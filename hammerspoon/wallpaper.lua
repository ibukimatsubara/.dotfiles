-- wallpaper.lua — lightweight random desktop wallpaper rotation

local M = {}

local HOME = os.getenv("HOME")
local WALLPAPER_DIR = HOME .. "/Pictures/Wallpapers/codex"
local INTERVAL_SECONDS = 60 * 60

local currentName = nil
local rotationTimer = nil
local screenWatcher = nil

local function wallpaperNames()
  local names = {}
  local attributes = hs.fs.attributes(WALLPAPER_DIR)
  if not attributes or attributes.mode ~= "directory" then
    return names
  end

  for file in hs.fs.dir(WALLPAPER_DIR) do
    local name = file:match("^(.*)%-qhd%.png$")
    if name and hs.fs.attributes(WALLPAPER_DIR .. "/" .. name .. "-macbook.png") then
      table.insert(names, name)
    end
  end

  table.sort(names)
  return names
end

local function variantForScreen(screen)
  local frame = screen:fullFrame()
  if frame.w / frame.h >= 1.7 then
    return "qhd"
  end
  return "macbook"
end

local function applyWallpaper(name)
  if not name then
    return false
  end

  for _, screen in ipairs(hs.screen.allScreens()) do
    local variant = variantForScreen(screen)
    local path = string.format("%s/%s-%s.png", WALLPAPER_DIR, name, variant)
    if hs.fs.attributes(path) then
      screen:desktopImageURL("file://" .. path)
    end
  end

  currentName = name
  return true
end

local function currentWallpaperName()
  local url = hs.screen.mainScreen():desktopImageURL()
  if type(url) ~= "string" then
    return nil
  end

  return url:match("/([^/]+)%-macbook%.png$")
      or url:match("/([^/]+)%-qhd%.png$")
end

function M.next()
  local names = wallpaperNames()
  if #names == 0 then
    return false
  end

  if #names == 1 then
    return applyWallpaper(names[1])
  end

  local nextName = currentName
  while nextName == currentName do
    nextName = names[math.random(#names)]
  end

  return applyWallpaper(nextName)
end

function M.start()
  math.randomseed(os.time())
  currentName = currentWallpaperName()

  if rotationTimer then
    rotationTimer:stop()
  end
  rotationTimer = hs.timer.doEvery(INTERVAL_SECONDS, M.next)

  if screenWatcher then
    screenWatcher:stop()
  end
  screenWatcher = hs.screen.watcher.new(function()
    hs.timer.doAfter(2, function()
      local names = wallpaperNames()
      if not currentName and #names > 0 then
        currentName = names[math.random(#names)]
      end
      applyWallpaper(currentName)
    end)
  end)
  screenWatcher:start()

  return M
end

return M
