-- Apply visual presets without restarting navigation or the break timer.
local M = {}
local HOME = os.getenv("HOME")
local SCRIPT = HOME .. "/.dotfiles/scripts/desktop-theme.sh"
local STATE = HOME .. "/.config/desktop-theme/current/theme.json"
local chooser, pendingTask = nil, nil
local hotkeys, reloadTasks = {}, {}
local barCorners = require("bar_corners")

local function commandPath(name)
  for _, prefix in ipairs({ "/opt/homebrew/bin/", "/usr/local/bin/", "/usr/bin/" }) do
    if hs.fs.attributes(prefix .. name) then return prefix .. name end
  end
end

local function reloadCommand(name, args)
  local path = commandPath(name)
  if not path then return end
  local task
  task = hs.task.new(path, function() reloadTasks[task] = nil end, args)
  if task then
    reloadTasks[task] = true
    if not task:start() then reloadTasks[task] = nil end
  end
end

function M.refresh()
  local data = hs.json.read(STATE)
  if type(data) ~= "table" then return false end
  wallpaper.start()
  barCorners.refresh(data)
  local app = hs.application.get("com.mitchellh.ghostty") or hs.application.get("Ghostty")
  if app and not app:selectMenuItem("Reload Configuration") then
    hs.eventtap.keyStroke({ "ctrl", "alt", "cmd" }, "r", 0, app)
  end
  reloadCommand("sketchybar", { "--reload" })
  local _, bordersRunning = hs.execute("/usr/bin/pgrep -x borders", false)
  if bordersRunning and data.colors then
    reloadCommand("borders", { "active_color=" .. data.colors.FOCUS_COLOR })
  end
  return true
end

local function run(args, callback)
  if pendingTask and pendingTask:isRunning() then return false end
  local arguments = { SCRIPT }
  for _, arg in ipairs(args) do table.insert(arguments, arg) end
  pendingTask = hs.task.new("/bin/bash", function(code, output, errors)
    pendingTask = nil
    if code ~= 0 then
      hs.alert.show("Theme: " .. (errors ~= "" and errors or "could not apply preset"), 3)
    elseif callback then
      callback(output)
    end
  end, arguments)
  if not pendingTask then return false end
  return not not pendingTask:start()
end

function M.apply(name)
  return run({ "apply", name, "--no-reload" }, function()
    M.refresh()
  end)
end

function M.next()
  return run({ "next", "--no-reload" }, function()
    M.refresh()
  end)
end

function M.pick()
  return run({ "list", "--json", "--no-reload" }, function(output)
    local entries = hs.json.decode(output)
    if not entries then return end
    local choices = {}
    for _, entry in ipairs(entries) do
      table.insert(choices, { text = entry.label, subText = entry.description, name = entry.name })
    end
    if not chooser then
      chooser = hs.chooser.new(function(choice)
        if choice then M.apply(choice.name) end
      end)
      chooser:placeholderText("Desktop theme")
      chooser:searchSubText(true)
    end
    chooser:choices(choices)
    chooser:query("")
    chooser:show()
  end)
end

function M.start()
  barCorners.start()
  for _, hotkey in ipairs(hotkeys) do hotkey:delete() end
  hotkeys = {
    hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "t", M.pick),
    hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "n", M.next),
    hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "w", function() wallpaper.next() end),
  }
  return M
end

return M
