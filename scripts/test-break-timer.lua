-- 実際の時間・音・キー入力を使わず、状態遷移と通知の重複を検証する。
-- 実行: lua scripts/test-break-timer.lua
local repo = arg[0]:match("^(.*)/scripts/[^/]+$") or "."
local root = os.tmpname()
os.remove(root)
local function quote(value) return "'" .. value:gsub("'", "'\\''") .. "'" end
assert(os.execute("mkdir -p " .. quote(root .. "/.config/break-timer") .. " "
    .. quote(root .. "/.cache/ghostty-break") .. " "
    .. quote(root .. "/.dotfiles/ghostty/shaders/scenes")))

local function write(path, body)
  local file = assert(io.open(path, "w"))
  file:write(body)
  file:close()
end
local function config(automatic)
  write(root .. "/.config/break-timer/config.lua", string.format([[
return { work_minutes = 2, fade_minutes = 0.5, break_minutes = 2,
  snooze_minutes = 2, auto_start_work = %s, auto_start_break = %s,
  sounds = true, warning_seconds = 60, wallpaper_enabled = false }
]], tostring(automatic), tostring(automatic)))
end
config(false)
write(root .. "/.dotfiles/ghostty/shaders/scenes/starry.tpl.glsl",
    "#define MODE {{MODE}}\n#define PROGRESS {{PROGRESS}}\n")

local originalGetenv = os.getenv
os.getenv = function(key)
  if key == "HOME" then return root end
  return originalGetenv(key)
end
local now, played, keys, arbitraryKeyTaps = 1000, {}, {}, 0
local function watcher(callback)
  return { callback = callback, start = function(self) return self end }
end
local soundObjects = {}
hs = {
  fs = { attributes = function() return { mode = "directory" } end },
  timer = {
    secondsSinceEpoch = function() return now end,
    doEvery = function(_, callback) return watcher(callback) end,
  },
  application = {
    get = function() return nil end,
    frontmostApplication = function()
      return { bundleID = function() return "com.mitchellh.ghostty" end }
    end,
    watcher = { activated = 1, new = function(callback) return watcher(callback) end },
  },
  eventtap = { new = function() arbitraryKeyTaps = arbitraryKeyTaps + 1 end },
  hotkey = { new = function(_, key, callback)
    local hotkey = { callback = callback,
      enable = function(self) self.enabled = true end,
      disable = function(self) self.enabled = false end }
    keys[key] = hotkey
    return hotkey
  end },
  alert = { show = function() end },
  menubar = { new = function()
    return { setTitle = function(self, title) self.title = title end,
      setMenu = function(self, callback) self.menu = callback end }
  end },
  pathwatcher = { new = function(_, callback) return watcher(callback) end },
  caffeinate = { watcher = {
    systemDidWake = 1, new = function(callback) return watcher(callback) end,
  } },
  audiodevice = { defaultOutputDevice = function()
    return { uid = function() return "test-output" end }
  end },
  sound = {
    getByFile = function(path)
      local kind = ({ ["warning-beep.mp3"] = "warning", ["timer-complete.mp3"] = "finished" })
          [path:match("([^/]+)$")]
      assert(kind, "unexpected timer sound: " .. path)
      local sound = {
        device = function(self, uid) self.output = uid end,
        volume = function(self, volume) self.level = volume end,
        stop = function() end,
        play = function(self)
          assert(self.output == "test-output")
          assert(self.level == 1)
          table.insert(played, kind)
          return self
        end,
      }
      soundObjects[kind] = sound
      return sound
    end,
    getByName = function() error("unexpected fallback") end,
  },
}

local function run()
  local timer = dofile(repo .. "/hammerspoon/break_timer.lua")
  local function state(expected)
    assert(timer.status():match("state=([^ ]+)") == expected, timer.status())
  end
  local function advance(seconds)
    now = now + seconds
    timer.timer.callback()
  end
  local function sounds(expected)
    assert(table.concat(played, ",") == expected, table.concat(played, ","))
  end

  state("waiting")
  advance(500)
  state("waiting")
  sounds("")
  assert(arbitraryKeyTaps == 0, "ordinary typing must not restart the timer")
  assert(keys.p.enabled and keys.o.enabled)
  keys.p.callback()
  state("work")
  advance(59)
  sounds("")
  advance(1)
  sounds("warning")
  advance(1)
  sounds("warning")
  advance(59)
  state("ready")
  sounds("warning,finished")
  advance(1000)
  state("ready")
  sounds("warning,finished")
  keys.p.callback()
  state("break")
  advance(60)
  sounds("warning,finished,warning")
  advance(1)
  sounds("warning,finished,warning")
  advance(59)
  state("waiting")
  sounds("warning,finished,warning,finished")
  advance(1000)
  state("waiting")
  sounds("warning,finished,warning,finished")

  keys.p.callback()
  timer.configWatcher.callback()
  state("waiting")
  keys.p.callback()
  timer.wakeWatcher.callback(hs.caffeinate.watcher.systemDidWake)
  state("waiting")
  keys.o.callback()
  assert(timer.status():match("enabled=false"))
  advance(500)
  keys.o.callback()
  state("waiting")
  keys.o.callback()
  keys.p.callback()
  state("work")
  assert(timer.status():match("enabled=true"))
  keys.o.callback()
  keys.p.callback() -- OFF直後でも新しい作業時間で再開する。
  state("work")
  assert(timer.refreshVisual())
  local visual = assert(io.open(root .. "/.cache/ghostty-break/break_state.glsl")):read("*a")
  assert(visual:match("#define MODE 4"), visual)

  played = {}
  timer.cfg.work = 30
  advance(1)
  sounds("")
  advance(29)
  state("ready")
  sounds("finished")
  timer.cfg.sounds = false
  keys.p.callback()
  advance(60)
  advance(60)
  state("waiting")
  sounds("finished")

  played = {}
  config(true)
  timer.configWatcher.callback()
  state("work")
  advance(120) -- 遅延した tick で、期限後に1分前通知を鳴らさない。
  state("fading")
  sounds("finished")
  advance(30)
  state("break")
  advance(120)
  state("work")
  sounds("finished,finished")

  config(false)
  timer.configWatcher.callback()
  keys.p.callback()
  timer.skip()
  state("break")
  keys.p.callback() -- スヌーズは明示操作なので許可する。
  state("snoozed")
  played = {}
  advance(60)
  advance(60)
  state("ready")
  sounds("warning,finished")
  assert(timer.refreshVisual())
  local snapshot = assert(io.open(root .. "/.cache/ghostty-break/tmux_status.tsv")):read("*a")
  assert(snapshot:match("^true\tready\t%d+\t0\n$"), snapshot)
  print("PASS: manual starts, warning/completion sounds, reload/wake, snooze, and automatic opt-in")
end

local ok, err = xpcall(run, debug.traceback)
os.getenv = originalGetenv
os.execute("rm -rf " .. quote(root))
if not ok then error(err) end
