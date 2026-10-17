-- wallpaper.lua — lightweight random desktop wallpaper rotation

local M = {}

local HOME = os.getenv("HOME")
local WALLPAPER_DIR = HOME .. "/Pictures/Wallpapers/codex"
local INTERVAL_SECONDS = 60 * 60

local currentName = nil
local rotationTimer = nil
local screenWatcher = nil
local activeTheme = nil

local function readTheme()
  local ok, data = pcall(hs.json.read, HOME .. "/.config/desktop-theme/current/theme.json")
  if ok and type(data) == "table" and type(data.wallpapers) == "table" then
    return data
  end
end

local function fileURL(path)
  return "file://" .. path:gsub("([^%w%-%._~/])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
end

local function wallpaperNames()
  local names = {}
  if activeTheme then
    for _, image in ipairs(activeTheme.wallpapers) do
      if hs.fs.attributes(image.path) then table.insert(names, image.id) end
    end
    return names
  end
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

  local themePath = nil
  if activeTheme then
    for _, image in ipairs(activeTheme.wallpapers) do
      if image.id == name then themePath = image.path; break end
    end
    if not themePath then return false end
  end
  local applied = false
  for _, screen in ipairs(hs.screen.allScreens()) do
    local path = themePath or string.format("%s/%s-%s.png", WALLPAPER_DIR, name, variantForScreen(screen))
    if hs.fs.attributes(path) then
      if screen:desktopImageURL(fileURL(path)) then applied = true end
    end
  end

  if applied then currentName = name end
  return applied
end

local function currentWallpaperName()
  local url = hs.screen.mainScreen():desktopImageURL()
  if type(url) ~= "string" then
    return nil
  end

  if activeTheme then
    for _, image in ipairs(activeTheme.wallpapers) do
      if url == fileURL(image.path) then return image.id end
    end
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

function M.stop()
  if rotationTimer then
    rotationTimer:stop()
  end
  if screenWatcher then
    screenWatcher:stop()
  end
end

function M.start()
  M.stop()
  activeTheme = readTheme()
  currentName = currentWallpaperName()
  if activeTheme then
    currentName = currentName or wallpaperNames()[1]
    applyWallpaper(currentName)
  end
  local interval = activeTheme and activeTheme.rotation_seconds or INTERVAL_SECONDS
  rotationTimer = hs.timer.doEvery(math.max(60, tonumber(interval) or INTERVAL_SECONDS), M.next)

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
