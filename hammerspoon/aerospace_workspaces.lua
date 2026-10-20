-- Preserve manual workspace assignments when AeroSpace re-detects windows on wake.
local M = {}
local FORMAT = "%{window-id}|%{workspace}|%{app-pid}|%{app-bundle-id}"
local EXCLUDED = { ["com.electron.aqua-voice"] = true, ["com.raycast.macos"] = true }
local windows, generation, attempts = {}, 0, 0
local sleeping, locked, recovering, started = false, false, false, false
local executable

local function stopTimer(name)
  if M[name] then M[name]:stop(); M[name] = nil end
end

local function cancel()
  generation = generation + 1
  stopTimer("retry")
  stopTimer("timeout")
  local task = M.task
  M.task = nil
  if task then task:terminate() end
end

-- One asynchronous CLI process at a time; neither polling nor wake events can
-- accumulate children if AeroSpace is unavailable or an AX request stalls.
local function run(args, callback)
  if M.task then return end
  local epoch, task = generation
  local function finished(code, output)
    if epoch ~= generation or M.task ~= task then return end
    M.task = nil
    stopTimer("timeout")
    callback(code == 0 and output or nil)
  end
  task = hs.task.new(executable, finished, args)
  if not task then callback(nil); return end
  M.task = task
  if not task:start() then M.task = nil; callback(nil); return end
  M.timeout = hs.timer.doAfter(2, function()
    if M.task ~= task then return end
    M.task = nil
    M.timeout = nil
    task:terminate()
    callback(nil)
  end)
end

local function parse(output)
  if not output then return nil end
  local result = {}
  for line in output:gmatch("[^\r\n]+") do
    local id, workspace, pid, app = line:match("^(%d+)|([^|]+)|(%d+)|([^|]*)$")
    if not id then return nil end
    if not EXCLUDED[app] then result[id] = { workspace = workspace, pid = pid, app = app } end
  end
  return result
end

local function snapshot()
  if not started or sleeping or locked or recovering or M.task then return end
  run({ "list-windows", "--all", "--format", FORMAT }, function(output)
    local current = parse(output)
    -- A failed/empty AX scan must not erase the last usable snapshot.
    if current and next(current) then windows = current end
  end)
end

local restore
local function restoreLater()
  stopTimer("retry")
  M.retry = hs.timer.doAfter(1, function()
    M.retry = nil
    restore()
  end)
end

restore = function()
  if not started or sleeping or locked or not recovering then return end
  attempts = attempts + 1
  run({ "list-windows", "--all", "--format", FORMAT }, function(output)
    local current, moves = parse(output), {}
    for id, previous in pairs(windows) do
      local window = current and current[id]
      -- A recycled window ID from a new app process is not the saved window.
      if window and window.pid == previous.pid and window.app == previous.app
          and window.workspace ~= previous.workspace then
        table.insert(moves, { "move-node-to-workspace", previous.workspace, "--window-id", id })
      end
    end
    local function nextMove(index)
      if sleeping or locked or not recovering then return end
      if moves[index] then
        run(moves[index], function(result)
          if result then M.restoredWindows = M.restoredWindows + 1 end
          nextMove(index + 1)
        end)
      elseif attempts < 6 then
        restoreLater()
      else
        recovering = false
        -- Keep the pre-sleep snapshot until normal polling can succeed again.
      end
    end
    nextMove(1)
  end)
end

local function suspend()
  -- Freeze the last healthy scan instead of querying Accessibility after macOS
  -- has begun making windows disappear. Ignore in-flight pre-sleep callbacks.
  cancel()
  recovering = false
end

local function resume()
  if sleeping or locked then return end
  cancel()
  attempts = 0
  recovering = next(windows) ~= nil
  if recovering then restoreLater() else snapshot() end
end

function M.start()
  if started then return M end
  for _, path in ipairs({ "/opt/homebrew/bin/aerospace", "/usr/local/bin/aerospace" }) do
    local attr = hs.fs.attributes(path)
    if attr and attr.mode == "file" then executable = path; break end
  end
  if not executable then return M end
  started = true
  M.restoredWindows = 0
  local events = hs.caffeinate.watcher
  M.watcher = events.new(function(event)
    if event == events.systemWillSleep or event == events.screensDidSleep then
      sleeping = true
      suspend()
    elseif event == events.screensDidLock then
      locked = true
      suspend()
    elseif event == events.systemDidWake or event == events.screensDidWake then
      sleeping = false
      resume()
    elseif event == events.screensDidUnlock then
      locked = false
      resume()
    end
  end):start()
  M.poll = hs.timer.doEvery(2, snapshot)
  snapshot()
  return M
end

function M.stop()
  started = false
  cancel()
  stopTimer("poll")
  if M.watcher then M.watcher:stop(); M.watcher = nil end
  windows, sleeping, locked, recovering = {}, false, false, false
end

function M.status()
  local count = 0
  for _ in pairs(windows) do count = count + 1 end
  return { enabled = started, trackedWindows = count, suspended = sleeping or locked,
    recovering = recovering, restoredWindows = M.restoredWindows or 0 }
end

return M
