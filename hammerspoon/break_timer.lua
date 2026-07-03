-- break_timer.lua — Ghostty 強制休憩タイマー
--
-- 30分作業 → 3分かけて画面の色が抜け・ぼやけ・星空に変わる → 3分休憩 →
-- 休憩明けは何かキーを押すと復帰して次の30分が始まる。
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
--   ⌘P           フェード/休憩中 = スヌーズ(+3分) / 作業中 = 残り時間表示
--   ⌘O           タイマー ON/OFF (確認ダイアログ付き)
--   何かキー      休憩明けに Ghostty 上で押すと再開(そのキー入力は飲み込まれる)
--   メニューバー   常時状態を表示(☀残り分数/🌙/☕/✨/⏸ OFF)。クリックで
--                ON/OFF・スヌーズ・今すぐ休憩・デモ

local M = {}

local HOME = os.getenv("HOME")
local CONFIG_PATH = HOME .. "/.config/break-timer/config.lua"
local GHOSTTY_CONFIG_PATH = HOME .. "/.dotfiles/ghostty/config"
local SCENES_DIR = HOME .. "/.dotfiles/ghostty/shaders/scenes/"
local STATE_DIR = HOME .. "/.cache/ghostty-break"
local STATE_PATH = STATE_DIR .. "/break_state.glsl"

-- 設定ファイルが無い/壊れているときの既定値
local DEFAULTS = {
  work_minutes = 30, fade_minutes = 3, break_minutes = 3, snooze_minutes = 3,
  scene = "starry", show_work_gauge = true, alerts = false,
  wallpaper_enabled = true, wallpaper_dir = HOME .. "/.dotfiles/ghostty/wallpapers",
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

-- state: work | fading | snoozed | break | waiting
local state = "work"
local phaseStart = hs.timer.secondsSinceEpoch()
local enabled = true
local demoMode = false
local template = nil
local lastMode, lastProgress = nil, nil

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

local function listWallpapers(dir)
  local files = {}
  local ok, iter, dirObj = pcall(hs.fs.dir, dir)
  if not ok or not iter then return files end
  for name in iter, dirObj do
    if name ~= "." and name ~= ".." then
      local path = dir .. "/" .. name
      local attr = hs.fs.attributes(path)
      local ext = name:match("%.([^%.]+)$")
      ext = ext and ext:lower()
      if attr and attr.mode == "file" and ({ jpg = true, jpeg = true, png = true, gif = true, webp = true })[ext] then
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
    image = chooseWallpaper(rotate)
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

  if image then upsertGhosttyConfig(lines, "background-image", image) end
  upsertGhosttyConfig(lines, "background-image-opacity", opacity)
  upsertGhosttyConfig(lines, "background-image-fit", wallpaperFit)

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
  scene = type(user.scene) == "string" and user.scene or DEFAULTS.scene
  showWorkGauge = user.show_work_gauge ~= false
  alertsEnabled = (user.alerts == true)
  wallpaperEnabled = user.wallpaper_enabled ~= false
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
local function notify(msg)
  if alertsEnabled then hs.alert.show(msg) end
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
  if mode == lastMode and progress == lastProgress then return end
  if not template and not loadTemplate() then return end
  local body = template
      :gsub("{{MODE}}", tostring(mode))
      :gsub("{{PROGRESS}}", string.format("%.4f", progress))
  local f = io.open(STATE_PATH, "w")
  if not f then return end
  f:write(body)
  f:close()
  lastMode, lastProgress = mode, progress
  reloadGhostty()
end

local enterState -- 前方宣言(wakeTap から参照するため)

-- 休憩明けにどのキーでも復帰できるようにする監視(waiting 中だけ動かす)。
-- Ghostty にフォーカスがあるときだけ反応し、他アプリでの入力は素通しする
local wakeTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(_)
  local fw = hs.application.frontmostApplication()
  if not (fw and fw:bundleID() == "com.mitchellh.ghostty") then return false end
  -- eventtap のコールバック内で重い処理(メニュー操作)をするとタップが
  -- タイムアウトで無効化されるため、復帰処理は次のループに逃がす
  hs.timer.doAfter(0, function() enterState("work") end)
  return true -- 復帰用のキー入力はアプリに渡さない
end)

-- ⌘P/⌘O は Ghostty フォーカス中だけ有効化する(他アプリのショートカットを奪わない)
local snoozeKey = hs.hotkey.new({ "cmd" }, "p", function()
  if not enabled then return end
  if state == "fading" or state == "break" then
    enterState("snoozed")
  elseif state == "work" or state == "snoozed" then
    local total = (state == "work") and cfg.work or cfg.snooze
    local remain = math.max(0, total - (hs.timer.secondsSinceEpoch() - phaseStart))
    hs.alert.show(string.format("⏳ 休憩まで あと%d分%02d秒", math.floor(remain / 60), math.floor(remain % 60)))
  end
end)

local toggleKey = hs.hotkey.new({ "cmd" }, "o", function()
  -- 押し間違い防止に確認ダイアログを挟む
  local title = enabled and "休憩タイマーを OFF にしますか?" or "休憩タイマーを ON にしますか?"
  local detail = enabled
      and "画面下端のゲージが消え、休憩の誘導が止まります"
      or ("作業 " .. math.floor(cfg.work / 60) .. "分のサイクルを開始します")
  local btn = hs.dialog.blockAlert(title, detail, "OK", "キャンセル")
  if btn == "OK" then M.toggle() end
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
    return "✨"
  end
  return "☀"
end

local function refreshMenubar()
  if menubar then menubar:setTitle(menuTitle()) end
end

if menubar then
  menubar:setMenu(function()
    local items = {
      { title = (enabled and "タイマーを OFF にする" or "タイマーを ON にする") .. " (⌘O)", fn = function() M.toggle() end },
      { title = "-" },
      { title = "今すぐ休憩へ", fn = function() enterState("fading") end, disabled = not enabled },
      { title = "デモ実行 (短縮サイクル)", fn = function() M.demo() end, disabled = not enabled },
    }
    if state == "fading" or state == "break" then
      table.insert(items, 1, { title = "スヌーズ +3分 (⌘P)", fn = function() enterState("snoozed") end })
    end
    return items
  end)
end

enterState = function(s)
  -- wakeTap とホットキーの二重発火で work が連続再入するのを防ぐ
  if s == "work" and state == "work" and hs.timer.secondsSinceEpoch() - phaseStart < 2 then return end
  local prevState = state
  state = s
  phaseStart = hs.timer.secondsSinceEpoch()
  if s ~= "waiting" then wakeTap:stop() end

  if s == "work" then
    if prevState == "waiting" then applyWallpaper(true, true) end
    if demoMode then
      demoMode = false
      loadConfig()
      hs.alert.show("🧪 デモ終了 — 通常設定で再開 (" .. math.floor(cfg.work / 60) .. "分)")
    else
      notify("▶ 作業スタート (" .. math.floor(cfg.work / 60) .. "分)")
    end
    setShader(workMode(), 0)
  elseif s == "fading" then
    notify("🌙 そろそろ休憩 — " .. math.floor(cfg.fade / 60) .. "分かけて休憩画面になります\n(⌘P でスヌーズ)")
    setShader(1, 0)
  elseif s == "snoozed" then
    notify("⏰ スヌーズ +" .. math.floor(cfg.snooze / 60) .. "分")
    setShader(workMode(), 0)
  elseif s == "break" then
    notify("☕ 休憩 (" .. math.floor(cfg.brk / 60) .. "分)")
    setShader(2, 0)
  elseif s == "waiting" then
    notify("✨ 休憩おわり — 何かキーを押すと再開")
    setShader(3, 0)
    wakeTap:start()
  end
  refreshMenubar()
end

local function tick()
  if not enabled then return end
  local el = hs.timer.secondsSinceEpoch() - phaseStart
  if state == "work" then
    if el >= cfg.work then enterState("fading") elseif showWorkGauge then setShader(4, el / cfg.work) end
  elseif state == "snoozed" then
    if el >= cfg.snooze then enterState("fading") elseif showWorkGauge then setShader(4, el / cfg.snooze) end
  elseif state == "fading" then
    if el >= cfg.fade then enterState("break") else setShader(1, el / cfg.fade) end
  elseif state == "break" then
    if el >= cfg.brk then enterState("waiting") else setShader(2, el / cfg.brk) end
  end
  -- waiting はキー入力待ちなので何もしない(明滅はシェーダーが iTime で勝手に動く)
  refreshMenubar()
end

function M.toggle(on)
  if on == nil then on = not enabled end
  enabled = on
  if enabled then
    applyWallpaper(true)
    enterState("work")
  else
    wakeTap:stop()
    applyWallpaper(false)
    setShader(0, 0)
    notify("⏸ 休憩タイマー OFF (⌘O か メニューバーで再開)")
    refreshMenubar()
  end
end

-- スリープ復帰時はサイクルを仕切り直す
M.wakeWatcher = hs.caffeinate.watcher.new(function(ev)
  if ev == hs.caffeinate.watcher.systemDidWake and enabled then
    enterState("work")
  end
end)
M.wakeWatcher:start()

-- 短縮サイクルで一通りの動きを確認する(終わったら自動で通常モードに戻る)
function M.demo()
  demoMode = true
  cfg.work, cfg.fade, cfg.brk, cfg.snooze = 8, 20, 12, 10
  hs.alert.show("🧪 デモ: 8秒作業 → 20秒フェード → 12秒休憩")
  enterState("work")
end

function M.skip() -- 今すぐフェードを始める
  enterState("fading")
end

function M.status()
  local el = math.floor(hs.timer.secondsSinceEpoch() - phaseStart)
  return string.format("state=%s elapsed=%ds enabled=%s", state, el, tostring(enabled))
end

-- 設定ファイルの変更を監視して即反映(サイクルは仕切り直し)
M.configWatcher = hs.pathwatcher.new(HOME .. "/.dotfiles/break-timer/", function(_)
  loadConfig()
  notify("🔄 休憩タイマー設定を再読み込み")
  applyWallpaper(enabled)
  if enabled then enterState("work") end
end):start()

-- シーンの GLSL 編集も監視して、いま表示中の画面に当て直す
M.sceneWatcher = hs.pathwatcher.new(SCENES_DIR, function(_)
  local m, p = lastMode, lastProgress
  template, lastMode = nil, nil
  if m then setShader(m, p or 0) end
end):start()

os.execute("mkdir -p '" .. STATE_DIR .. "'")
loadConfig()
applyWallpaper(enabled)
setShader(workMode(), 0)
M.timer = hs.timer.doEvery(1, tick)
phaseStart = hs.timer.secondsSinceEpoch()
refreshMenubar()
syncKeys()

return M
