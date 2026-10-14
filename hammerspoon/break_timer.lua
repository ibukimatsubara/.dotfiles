-- break_timer.lua — Ghostty 強制休憩タイマー
--
-- 30分作業 → 休憩の開始待ち → 3分休憩 → 作業の開始待ち。
-- 作業・休憩は明示的に開始する。残り1分と終了時に通知音が鳴る。
--
-- 設定: ~/.config/break-timer/config.lua (実体は ~/.dotfiles/break-timer/config.lua)
-- 時間・休憩シーン・下端ゲージ・Ghostty 壁紙を変更できる。保存すると自動で再読み込み。
-- シーンの GLSL (ghostty/shaders/scenes/*.tpl.glsl) を編集した場合も即時反映。
--
-- 見た目は全部 Ghostty のカスタムシェーダー
-- (~/.dotfiles/ghostty/shaders/break_screen.tpl.glsl) が担当。
-- このモジュールはテンプレートの {{MODE}}/{{PROGRESS}} を埋めた状態ファイルを
-- ~/.cache/ghostty-break/break_state.glsl に書き出し、Ghostty に設定リロードを
-- かけることで進行を伝える。
--
-- 操作 (⌘P/⌘O は Ghostty にフォーカスがあるときだけ有効。他アプリでは
-- 本来の「印刷」「開く」のまま):
--   ⌘P           開始待ち = 作業/休憩をスタート
--                フェード/休憩中 = スヌーズ(+3分) / 作業中 = 残り時間表示
--   ⌘O           タイマー ON/OFF
--   メニューバー   常時状態を表示(☀残り分数/🌙/☕/開始待ち/⏸ OFF)

local M = {}

local HOME = os.getenv("HOME")
local CONFIG_PATH = HOME .. "/.config/break-timer/config.lua"
local GHOSTTY_CONFIG_PATH = HOME .. "/.dotfiles/ghostty/config"
local SCENES_DIR = HOME .. "/.dotfiles/ghostty/shaders/scenes/"
local STATE_DIR = HOME .. "/.cache/ghostty-break"
local STATE_PATH = STATE_DIR .. "/break_state.glsl"
local TIMER_STATUS_PATH = STATE_DIR .. "/tmux_status.tsv"
local SOUND_DIR = HOME .. "/.dotfiles/break-timer/sounds/"
local SOUND_FILES = { warning = "warning-beep.mp3", finished = "timer-complete.mp3" }
local WALLPAPER_CACHE_DIR = HOME .. "/.cache/ghostty-wallpapers"
local NATIVE_WALLPAPER_EXT = { jpg = true, jpeg = true, png = true }
local SOURCE_WALLPAPER_EXT = {
  jpg = true, jpeg = true, png = true, webp = true, gif = true,
  heic = true, heif = true, tif = true, tiff = true, bmp = true, avif = true,
}

-- 設定ファイルが無い/壊れているときの既定値
local DEFAULTS = {
  work_minutes = 30, fade_minutes = 3, break_minutes = 3, snooze_minutes = 3,
  scene = "starry", show_work_gauge = true, alerts = false,
  auto_start_work = false, auto_start_break = false,
  sounds = true, sound_volume = 1.0, warning_seconds = 60,
  wallpaper_enabled = false, wallpaper_dir = HOME .. "/.dotfiles/ghostty/wallpapers",
  wallpaper_opacity = 0.3, wallpaper_fit = "contain", wallpaper_pick = "random",
}
local cfg = { work = 1800, fade = 180, brk = 180, snooze = 180 }
M.cfg = cfg
local scene = DEFAULTS.scene
local showWorkGauge = DEFAULTS.show_work_gauge
local alertsEnabled = DEFAULTS.alerts
local templatePath = SCENES_DIR .. DEFAULTS.scene .. ".tpl.glsl"
local wallpaperEnabled = DEFAULTS.wallpaper_enabled
local wallpaperDir = DEFAULTS.wallpaper_dir
local wallpaperOpacity = DEFAULTS.wallpaper_opacity
local wallpaperFit = DEFAULTS.wallpaper_fit
local wallpaperPick = DEFAULTS.wallpaper_pick
local currentWallpaper = nil
local reloadGhostty
math.randomseed(os.time())

-- state: work | fading | snoozed | break | ready (休憩待ち) | waiting (作業待ち)
local state = "waiting"
local phaseStart = hs.timer.secondsSinceEpoch()
local enabled = true
local demoMode = false
local template = nil
local lastMode, lastProgress = nil, nil
local lastTimerStatusBody = nil
local warningPlayed = false
local sounds = {}

local function loadTemplate()
  local f = io.open(templatePath, "r")
  if not f then f = io.open(SCENES_DIR .. "starry.tpl.glsl", "r") end -- シーン名が不正なら星空に
  if not f then return false end
  template = f:read("*a")
  f:close()
  return true
end

local function fileExists(path)
  local f = io.open(path, "r")
  if not f then return false end
  f:close()
  return true
end

local function readFile(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local body = f:read("*a")
  f:close()
  return body
end

local function writeFile(path, body)
  local f = io.open(path, "w")
  if not f then return false end
  f:write(body)
  f:close()
  return true
end

local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function portablePath(path)
  if path:sub(1, #HOME + 1) == HOME .. "/" then
    return "~" .. path:sub(#HOME + 1)
  end
  return path
end

local function ensureStateDir()
  local attr = hs.fs.attributes(STATE_DIR)
  if attr then return attr.mode == "directory" end

  local ok = os.execute("mkdir -p " .. shellQuote(STATE_DIR))
  if ok ~= true and ok ~= 0 then return false end
  attr = hs.fs.attributes(STATE_DIR)
  return attr ~= nil and attr.mode == "directory"
end

local function fileExt(path)
  local ext = path:match("%.([^%.]+)$")
  return ext and ext:lower() or ""
end

local function magickPath()
  for _, path in ipairs({ "/opt/homebrew/bin/magick", "/usr/local/bin/magick" }) do
    if fileExists(path) then return path end
  end
  return "magick"
end

local function wallpaperCachePath(path)
  local safe = path:gsub("[^%w%._%-]", "_")
  return WALLPAPER_CACHE_DIR .. "/" .. safe .. ".png"
end

local function hasNativeWallpaperSibling(path)
  if NATIVE_WALLPAPER_EXT[fileExt(path)] then return false end

  local dir = path:match("^(.*)/[^/]+$") or "."
  local filename = path:match("([^/]+)$") or path
  local stem = filename:gsub("%.[^%.]+$", "")
  for _, ext in ipairs({ "jpg", "jpeg", "png" }) do
    if fileExists(dir .. "/" .. stem .. "." .. ext) then return true end
  end
  return false
end

local function prepareWallpaper(path)
  if NATIVE_WALLPAPER_EXT[fileExt(path)] then return path end

  local output = wallpaperCachePath(path)
  os.execute("mkdir -p " .. shellQuote(WALLPAPER_CACHE_DIR))

  local src = hs.fs.attributes(path)
  local dst = hs.fs.attributes(output)
  if not dst or (src and src.modification > dst.modification) then
    local ok = os.execute(magickPath() .. " " .. shellQuote(path .. "[0]") .. " " .. shellQuote(output))
    if ok ~= true and ok ~= 0 then return nil end
  end

  return output
end

local function listWallpapers(dir)
  local files = {}
  local ok, iter, dirObj = pcall(hs.fs.dir, dir)
  if not ok or not iter then return files end
  for name in iter, dirObj do
    if name ~= "." and name ~= ".." then
      local path = dir .. "/" .. name
      local attr = hs.fs.attributes(path)
      local ext = fileExt(name)
      if attr and attr.mode == "file" and SOURCE_WALLPAPER_EXT[ext] and not hasNativeWallpaperSibling(path) then
        table.insert(files, path)
      end
    end
  end
  table.sort(files)
  return files
end

local function chooseWallpaper(avoidCurrent)
  local files = listWallpapers(wallpaperDir)
  if #files == 0 then return nil end
  if wallpaperPick == "first" then return files[1] end
  if wallpaperPick == "keep" and currentWallpaper and fileExists(currentWallpaper) then return currentWallpaper end
  if avoidCurrent and currentWallpaper and #files > 1 then
    local candidates = {}
    for _, path in ipairs(files) do
      if path ~= currentWallpaper then table.insert(candidates, path) end
    end
    if #candidates > 0 then return candidates[math.random(#candidates)] end
  end
  return files[math.random(#files)]
end

local function upsertGhosttyConfig(lines, key, value)
  local pattern = "^%s*" .. key:gsub("%-", "%%-") .. "%s*="
  local replacement = key .. " = " .. value
  if key == "background-image" then
    for i = #lines, 1, -1 do
      if lines[i]:match(pattern) then table.remove(lines, i) end
    end
    local insertAt = #lines + 1
    for i, line in ipairs(lines) do
      if line:match("^%s*background%-image%-opacity%s*=") then
        insertAt = i
        break
      end
    end
    table.insert(lines, insertAt, replacement)
    return
  end

  local replaced = false
  for i, line in ipairs(lines) do
    if line:match(pattern) then
      if not replaced then
        lines[i] = replacement
        replaced = true
      else
        lines[i] = "# " .. line
      end
    end
  end
  if not replaced then
    table.insert(lines, replacement)
  end
end

local function applyWallpaper(visible, rotate)
  local body = readFile(GHOSTTY_CONFIG_PATH)
  if not body then return end

  local image = currentWallpaper
  if visible and wallpaperEnabled then
    local sourceImage = chooseWallpaper(rotate)
    image = sourceImage and prepareWallpaper(sourceImage)
  end

  local opacity = "0"
  if visible and wallpaperEnabled and image then
    currentWallpaper = image
    opacity = string.format("%.3f", wallpaperOpacity):gsub("0+$", ""):gsub("%.$", "")
  end

  local lines = {}
  for line in (body .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end
  if body:sub(-1) == "\n" and lines[#lines] == "" then
    table.remove(lines)
  end

  if wallpaperEnabled then
    if image then upsertGhosttyConfig(lines, "background-image", portablePath(image)) end
    upsertGhosttyConfig(lines, "background-image-opacity", opacity)
    upsertGhosttyConfig(lines, "background-image-fit", wallpaperFit)
  else
    currentWallpaper = nil
    for i = #lines, 1, -1 do
      if lines[i]:match("^%s*background%-image%s*=")
          or lines[i]:match("^%s*background%-image%-opacity%s*=")
          or lines[i]:match("^%s*background%-image%-fit%s*=") then
        table.remove(lines, i)
      end
    end
  end

  local nextBody = table.concat(lines, "\n") .. "\n"
  if nextBody ~= body and writeFile(GHOSTTY_CONFIG_PATH, nextBody) then
    reloadGhostty()
  end
end

-- 設定ファイルを読んで反映する
local function loadConfig()
  local user = {}
  local ok, loaded = pcall(dofile, CONFIG_PATH)
  if ok and type(loaded) == "table" then user = loaded end
  local function num(key) return tonumber(user[key]) or DEFAULTS[key] end
  cfg.work   = num("work_minutes") * 60
  cfg.fade   = num("fade_minutes") * 60
  cfg.brk    = num("break_minutes") * 60
  cfg.snooze = num("snooze_minutes") * 60
  cfg.autoStartWork = user.auto_start_work == true
  cfg.autoStartBreak = user.auto_start_break == true
  cfg.sounds = user.sounds ~= false
  cfg.soundVolume = math.max(0, math.min(1, num("sound_volume")))
  cfg.warningSeconds = math.max(0, num("warning_seconds"))
  scene = type(user.scene) == "string" and user.scene or DEFAULTS.scene
  showWorkGauge = user.show_work_gauge ~= false
  alertsEnabled = (user.alerts == true)
  if user.wallpaper_enabled == nil then
    wallpaperEnabled = DEFAULTS.wallpaper_enabled
  else
    wallpaperEnabled = user.wallpaper_enabled == true
  end
  wallpaperDir = type(user.wallpaper_dir) == "string" and user.wallpaper_dir or DEFAULTS.wallpaper_dir
  wallpaperOpacity = math.max(0, math.min(1, tonumber(user.wallpaper_opacity) or DEFAULTS.wallpaper_opacity))
  wallpaperFit = type(user.wallpaper_fit) == "string" and user.wallpaper_fit or DEFAULTS.wallpaper_fit
  wallpaperPick = type(user.wallpaper_pick) == "string" and user.wallpaper_pick or DEFAULTS.wallpaper_pick
  templatePath = SCENES_DIR .. scene .. ".tpl.glsl"
  template = nil -- 次の setShader でシーンを読み直す
end
M.reloadConfig = loadConfig

-- 作業/スヌーズ中のシェーダーモード(下端ゲージの有無で切り替え)
local function workMode() return showWorkGauge and 4 or 0 end

-- 状態遷移などで自動的に出る通知。既定では出さない(定例・画面共有への
-- 誤爆防止)。状態は Ghostty 内の表示(下端ゲージ/フェード/星空/明滅)で分かる
local feedbackStyle = {
  textFont = ".AppleSystemUIFont", textSize = 14,
  textColor = { white = 0.94, alpha = 1 },
  fillColor = { red = 0.12, green = 0.12, blue = 0.16, alpha = 0.96 },
  strokeWidth = 0, radius = 8, padding = 10,
  atScreenEdge = 2, fadeInDuration = 0.1, fadeOutDuration = 0.15,
}
local feedbackAlert
local function showFeedback(msg)
  if feedbackAlert then hs.alert.closeSpecific(feedbackAlert, 0) end
  feedbackAlert = hs.alert.show(msg, feedbackStyle, 3)
end

local function notify(msg)
  if alertsEnabled then showFeedback(msg) end
end

-- オブジェクトを保持し、通知をポップアップ設定や通知センターに依存させない。
local function playSound(kind)
  if not cfg.sounds then return false end
  if not sounds[kind] then
    sounds[kind] = hs.sound.getByFile(SOUND_DIR .. SOUND_FILES[kind])
        or hs.sound.getByName(kind == "warning" and "Tink" or "Ping")
  end
  local sound = sounds[kind]
  if not sound then return false end
  local output = hs.audiodevice.defaultOutputDevice()
  if output then sound:device(output:uid()) end
  sound:stop()
  sound:volume(cfg.soundVolume)
  return sound:play() ~= false
end

function M.testSound(kind)
  return playSound(kind == "warning" and "warning" or "finished")
end

reloadGhostty = function()
  local app = hs.application.get("com.mitchellh.ghostty") or hs.application.get("Ghostty")
  if not app then return end
  if not app:selectMenuItem("Reload Configuration") then
    -- メニューが見つからない場合は ghostty 側の keybind (reload_config) に送る
    hs.eventtap.keyStroke({ "ctrl", "alt", "cmd" }, "r", 0, app)
  end
end

-- 状態ファイルを書き換えて Ghostty に反映。内容が変わらないときは何もしない
local function setShader(mode, progress)
  progress = math.floor(progress * 50 + 0.5) / 50 -- 0.02刻みに量子化してリロード頻度を抑える
  if mode == lastMode and progress == lastProgress and fileExists(STATE_PATH) then return true end
  if not ensureStateDir() then return false end
  if not template and not loadTemplate() then return false end
  local body = template
      :gsub("{{MODE}}", tostring(mode))
      :gsub("{{PROGRESS}}", string.format("%.4f", progress))
  local f = io.open(STATE_PATH, "w")
  if not f then return false end
  f:write(body)
  f:close()
  lastMode, lastProgress = mode, progress
  reloadGhostty()
  return true
end

-- tmux はこの小さなスナップショットから残り時間を計算する。
-- 毎秒 Hammerspoon CLI を起動せず、状態が変わったときだけ atomic に更新する。
local function writeTimerStatus()
  local durations = {
    work = cfg.work,
    snoozed = cfg.snooze,
    fading = cfg.fade,
    ["break"] = cfg.brk,
    ready = 0,
    waiting = 0,
  }
  local duration = enabled and (durations[state] or 0) or 0
  local body = table.concat({
    tostring(enabled),
    state,
    tostring(math.floor(phaseStart)),
    tostring(math.floor(duration)),
  }, "\t") .. "\n"

  if body == lastTimerStatusBody and fileExists(TIMER_STATUS_PATH) then return true end
  if not ensureStateDir() then return false end

  local tmpPath = TIMER_STATUS_PATH .. ".tmp"
  if not writeFile(tmpPath, body) then return false end
  local ok = os.rename(tmpPath, TIMER_STATUS_PATH)
  if not ok then
    os.remove(tmpPath)
    return false
  end

  lastTimerStatusBody = body
  return true
end

local enterState

function M.showStatus()
  if not enabled then return showFeedback("タイマー OFF") end
  if state == "waiting" then return showFeedback("作業の開始待ち · ⌘P") end
  if state == "ready" then return showFeedback("休憩の開始待ち · ⌘P") end
  local total = ({ work = cfg.work, snoozed = cfg.snooze, fading = cfg.fade, ["break"] = cfg.brk })[state]
  local remain = math.max(0, total - (hs.timer.secondsSinceEpoch() - phaseStart))
  showFeedback(string.format("%s  %02d:%02d", state == "break" and "休憩残り" or "休憩まで",
      math.floor(remain / 60), math.floor(remain % 60)))
end

-- ⌘P/⌘O は Ghostty フォーカス中だけ有効化する(他アプリのショートカットを奪わない)
local snoozeKey = hs.hotkey.new({ "cmd" }, "p", function()
  if not enabled or state == "waiting" or state == "ready" then
    M.start()
  elseif state == "fading" or state == "break" then
    enterState("snoozed")
  elseif state == "work" or state == "snoozed" then
    M.showStatus()
  end
end)

local toggleKey = hs.hotkey.new({ "cmd" }, "o", function()
  M.toggle()
end)

local function syncKeys()
  local fw = hs.application.frontmostApplication()
  if fw and fw:bundleID() == "com.mitchellh.ghostty" then
    snoozeKey:enable()
    toggleKey:enable()
  else
    snoozeKey:disable()
    toggleKey:disable()
  end
end

M.appWatcher = hs.application.watcher.new(function(_, event, _)
  if event == hs.application.watcher.activated then syncKeys() end
end)
M.appWatcher:start()

-- メニューバーの常時状態表示
local menubar = hs.menubar.new()
M.menubar = menubar

local function menuTitle()
  if not enabled then return "⏸ OFF" end
  local el = hs.timer.secondsSinceEpoch() - phaseStart
  if state == "work" then
    return string.format("☀ %d分", math.max(0, math.ceil((cfg.work - el) / 60)))
  elseif state == "snoozed" then
    return string.format("⏰ %d分", math.max(0, math.ceil((cfg.snooze - el) / 60)))
  elseif state == "fading" then
    return "🌙"
  elseif state == "break" then
    local remain = math.max(0, cfg.brk - el)
    return string.format("☕ %d:%02d", math.floor(remain / 60), math.floor(remain % 60))
  elseif state == "waiting" then
    return "▶ 作業待ち"
  elseif state == "ready" then
    return "☕ 休憩待ち"
  end
  return "☀"
end

local function refreshMenubar()
  if menubar then menubar:setTitle(menuTitle()) end
  writeTimerStatus()
end

if menubar then
  menubar:setMenu(function()
    local items = {
      { title = (enabled and state == "ready" and "休憩" or "作業") .. "をスタート (⌘P)",
        fn = function() M.start() end,
        disabled = enabled and state ~= "waiting" and state ~= "ready" },
      { title = (enabled and "タイマーを OFF にする" or "タイマーを ON にする") .. " (⌘O)", fn = function() M.toggle() end },
      { title = "-" },
      { title = "今すぐ休憩へ", fn = function() M.skip() end, disabled = not enabled },
      { title = "通知音をテスト", fn = function() M.testSound("warning") end },
      { title = "デモ実行 (短縮サイクル)", fn = function() M.demo() end, disabled = not enabled },
    }
    if state == "fading" or state == "break" then
      table.insert(items, 1, { title = "スヌーズ +3分 (⌘P)", fn = function() enterState("snoozed") end })
    end
    return items
  end)
end

enterState = function(s)
  local prevState = state
  state = s
  phaseStart = hs.timer.secondsSinceEpoch()
  warningPlayed = false

  if s == "work" then
    if prevState == "waiting" then applyWallpaper(true, true) end
    if demoMode then
      demoMode = false
      loadConfig()
      showFeedback("デモ終了 · 作業 " .. math.floor(cfg.work / 60) .. "分")
    else
      notify("作業スタート · " .. math.floor(cfg.work / 60) .. "分")
    end
    setShader(workMode(), 0)
  elseif s == "fading" then
    notify("休憩まで " .. math.floor(cfg.fade / 60) .. "分 · ⌘P で延長")
    setShader(1, 0)
  elseif s == "snoozed" then
    notify("スヌーズ +" .. math.floor(cfg.snooze / 60) .. "分")
    setShader(workMode(), 0)
  elseif s == "break" then
    notify("休憩スタート · " .. math.floor(cfg.brk / 60) .. "分")
    setShader(2, 0)
  elseif s == "ready" then
    notify("作業おわり · ⌘P で休憩")
    setShader(0, 0)
  elseif s == "waiting" then
    notify("作業の開始待ち · ⌘P")
    setShader(0, 0)
  end
  refreshMenubar()
end

local function tick()
  if not enabled then
    refreshMenubar()
    return
  end
  local el = hs.timer.secondsSinceEpoch() - phaseStart
  local total = ({ work = cfg.work, snoozed = cfg.snooze, ["break"] = cfg.brk })[state]
  if total and total > cfg.warningSeconds and cfg.warningSeconds > 0
      and not warningPlayed and el >= total - cfg.warningSeconds and el < total then
    warningPlayed = true
    playSound("warning")
  end
  if state == "work" then
    if el >= cfg.work then
      playSound("finished")
      enterState(cfg.autoStartBreak and "fading" or "ready")
    elseif showWorkGauge then setShader(4, el / cfg.work) end
  elseif state == "snoozed" then
    if el >= cfg.snooze then
      playSound("finished")
      enterState(cfg.autoStartBreak and "fading" or "ready")
    elseif showWorkGauge then setShader(4, el / cfg.snooze) end
  elseif state == "fading" then
    if el >= cfg.fade then enterState("break") else setShader(1, el / cfg.fade) end
  elseif state == "break" then
    if el >= cfg.brk then
      playSound("finished")
      enterState(cfg.autoStartWork and "work" or "waiting")
    else setShader(2, el / cfg.brk) end
  end
  -- 開始待ちの間は何もしない。普通のキー入力では再開しない。
  refreshMenubar()
end

function M.refreshVisual()
  local elapsed = hs.timer.secondsSinceEpoch() - phaseStart
  local function progress(total)
    if total <= 0 then return 1 end
    return math.max(0, math.min(1, elapsed / total))
  end

  if not enabled then return setShader(0, 0) end
  if state == "work" then return setShader(workMode(), progress(cfg.work)) end
  if state == "snoozed" then return setShader(workMode(), progress(cfg.snooze)) end
  if state == "fading" then return setShader(1, progress(cfg.fade)) end
  if state == "break" then return setShader(2, progress(cfg.brk)) end
  if state == "waiting" or state == "ready" then return setShader(0, 0) end
  return false
end

function M.start()
  if not enabled then
    enabled = true
    applyWallpaper(true)
    enterState("work")
  elseif state == "ready" then
    enterState("break")
  elseif state == "waiting" then
    enterState("work")
  end
end

function M.toggle(on)
  if on == nil then on = not enabled end
  enabled = on
  if enabled then
    applyWallpaper(true)
    enterState(cfg.autoStartWork and "work" or "waiting")
  else
    applyWallpaper(false)
    setShader(0, 0)
    notify("タイマー OFF · ⌘O で再開")
    refreshMenubar()
  end
end

-- スリープ復帰時も、手動モードでは作業の開始を待つ
M.wakeWatcher = hs.caffeinate.watcher.new(function(ev)
  if ev == hs.caffeinate.watcher.systemDidWake and enabled then
    enterState(cfg.autoStartWork and "work" or "waiting")
  end
end)
M.wakeWatcher:start()

-- 短縮サイクルで確認する。通常設定は次の作業開始時に復元する。
function M.demo()
  if not enabled then return end
  demoMode = true
  cfg.work, cfg.fade, cfg.brk, cfg.snooze = 8, 20, 12, 10
  showFeedback(cfg.autoStartBreak
      and "デモ: 8秒作業 → 20秒フェード → 12秒休憩"
      or "デモ: 8秒作業 → ⌘Pで12秒休憩 → ⌘Pで通常設定")
  enterState("work")
end

function M.skip() -- 明示操作で今すぐ休憩を始める
  if enabled then enterState(cfg.autoStartBreak and "fading" or "break") end
end

function M.status()
  local el = math.floor(hs.timer.secondsSinceEpoch() - phaseStart)
  return string.format("state=%s elapsed=%ds enabled=%s", state, el, tostring(enabled))
end

-- 設定ファイルの変更を監視して即反映(サイクルは仕切り直し)
M.configWatcher = hs.pathwatcher.new(HOME .. "/.dotfiles/break-timer/", function(_)
  loadConfig()
  notify("タイマー設定を再読み込み")
  applyWallpaper(enabled)
  if enabled then enterState(cfg.autoStartWork and "work" or "waiting") end
end):start()

-- シーンの GLSL 編集も監視して、いま表示中の画面に当て直す
M.sceneWatcher = hs.pathwatcher.new(SCENES_DIR, function(_)
  local m, p = lastMode, lastProgress
  template, lastMode = nil, nil
  if m then setShader(m, p or 0) end
end):start()

ensureStateDir()
loadConfig()
applyWallpaper(enabled)
enterState(cfg.autoStartWork and "work" or "waiting")
M.timer = hs.timer.doEvery(1, tick)
phaseStart = hs.timer.secondsSinceEpoch()
refreshMenubar()
syncKeys()

return M
