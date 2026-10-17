-- Test wallpaper selection without changing the real desktop.
local home = os.getenv("HOME")
local root = home .. "/Pictures/Wallpapers/codex"
local activeTheme = nil
local applied, timers = {}, {}
local legacyFiles = {
  "busy-room-qhd.png", "busy-room-macbook.png",
  "landscape-qhd.png", "landscape-macbook.png",
}
local screen = {}
function screen:fullFrame() return { w = 1680, h = 1050 } end
function screen:desktopImageURL(url)
  if url then applied[#applied + 1] = url; self.url = url; return true end
  return self.url
end
local external = {}
function external:fullFrame() return { w = 3440, h = 1440 } end
function external:desktopImageURL(url)
  if url then self.url = url; return true end
  return self.url
end
hs = {
  fs = {
    attributes = function(path)
      if path == root then return { mode = "directory" } end
      if path:find("/Pictures/Wallpapers/") then return { mode = "file" } end
    end,
    dir = function() local i = 0; return function() i = i + 1; return legacyFiles[i] end end,
  },
  json = { read = function() return activeTheme end },
  screen = {
    allScreens = function() return {screen, external} end,
    mainScreen = function() return screen end,
    watcher = {new = function(fn)
      return {start = function() end, stop = function() end, callback = fn}
    end},
  },
  timer = {
    doEvery = function(interval, fn)
      local timer = {interval = interval, callback = fn, stopped = false}
      function timer:stop() self.stopped = true end
      function timer:running() return not self.stopped end
      timers[#timers + 1] = timer
      return timer
    end,
    doAfter = function(_, fn) fn() end,
  },
}
local wallpaper = dofile("hammerspoon/wallpaper.lua")
activeTheme = {name = "quiet", rotation_seconds = 7200, wallpapers = {
  {id = "coast", path = home .. "/Pictures/Wallpapers/themes/quiet/coast.png"},
  {id = "sky", path = home .. "/Pictures/Wallpapers/themes/quiet/sky.png"},
}}
wallpaper.start()
assert(screen.url and screen.url:match("/quiet/coast.png$"), "startup should apply the active theme")
wallpaper.next()
assert(screen.url:match("/quiet/sky.png$"), "rotation should exclude legacy wallpapers")
wallpaper.next()
assert(screen.url:match("/quiet/coast.png$"), "rotation should return to the other theme image")
assert(timers[#timers].interval == 7200, "use theme rotation interval")
local previousTimer = timers[#timers]
activeTheme = {name = "single", rotation_seconds = 3600, wallpapers = {
  {id = "one", path = home .. "/Pictures/Wallpapers/themes/single/one image.png"},
}}
wallpaper.start()
assert(previousTimer.stopped, "theme switches must replace the previous timer")
assert(wallpaper.next(), "a single wallpaper must not loop forever")
assert(screen.url:match("/single/one%%20image.png$"), "encode spaces in file URLs")
activeTheme = nil
screen.url = "file://" .. root .. "/landscape-macbook.png"
wallpaper.start()
wallpaper.next()
assert(screen.url == "file://" .. root .. "/busy-room-macbook.png", "keep legacy MacBook fallback")
assert(external.url == "file://" .. root .. "/busy-room-qhd.png", "keep external-screen variant")
print("PASS: themed rotation, restart, single image, URL encoding, legacy screen variants")
