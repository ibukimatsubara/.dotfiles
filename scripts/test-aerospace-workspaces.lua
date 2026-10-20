-- Run with lua, or: hs -A -c 'return dofile(os.getenv("HOME") .. "/.dotfiles/scripts/test-aerospace-workspaces.lua")'
-- Mock every command and power event; never move actual windows or sleep the Mac.
local source = debug.getinfo(1, "S").source:sub(2)
local repo = source:match("^(.*)/scripts/[^/]+$") or "."
local tests = 0

local function harness()
  local pending, calls = {}, {}
  local function timer(callback)
    return { active = true, stop = function(self) self.active = false end,
      fire = function(self) if self.active then self.active = false; callback() end end }
  end
  local events = { systemWillSleep = 1, systemDidWake = 2, screensDidSleep = 3,
    screensDidWake = 4, screensDidLock = 5, screensDidUnlock = 6 }
  local eventCallback
  local fake = {
    fs = { attributes = function() return { mode = "file" } end },
    timer = { doAfter = function(_, callback) return timer(callback) end,
      doEvery = function(_, callback)
        local value = timer(callback)
        value.fire = function(self) if self.active then callback() end end
        return value
      end },
    caffeinate = { watcher = events },
    task = { new = function(path, callback, args)
      assert(path == "/opt/homebrew/bin/aerospace")
      return { callback = callback, args = args,
        start = function(self)
          pending[#pending + 1] = self
          calls[#calls + 1] = table.concat(args, " ")
          return self
        end,
        terminate = function(self) self.terminated = true end }
    end },
  }
  events.new = function(callback)
    eventCallback = callback
    return { start = function(self) return self end, stop = function() end }
  end
  local module = assert(loadfile(repo .. "/hammerspoon/aerospace_workspaces.lua", "t",
    setmetatable({ hs = fake }, { __index = _G })))().start()
  local h = { module = module, pending = pending, calls = calls }
  function h.finish(output, code)
    local task = assert(table.remove(pending, 1), "expected a CLI call")
    task.callback(code or 0, output or "", "")
    return task
  end
  function h.event(name) eventCallback(assert(events[name])) end
  function h.cycle(output, code)
    assert(module.retry, "expected recovery retry"):fire()
    h.finish(output, code)
    while #pending > 0 do
      assert(pending[1].args[1] == "move-node-to-workspace")
      h.finish()
    end
  end
  function h.moves()
    local moves = {}
    for _, call in ipairs(calls) do
      if call:match("^move%-node") then moves[#moves + 1] = call end
    end
    table.sort(moves)
    return table.concat(moves, "\n")
  end
  return h
end

local BEFORE = "11|1|100|com.microsoft.VSCode\n12|7|100|com.microsoft.VSCode\n"
local COLLAPSED = "11|4|100|com.microsoft.VSCode\n12|4|100|com.microsoft.VSCode\n"
local function test(name, callback)
  callback()
  tests = tests + 1
  print("PASS: " .. name)
end

test("restore separate windows of the same app without switching focus", function()
  local h = harness()
  h.finish(BEFORE)
  h.event("systemWillSleep")
  h.module.poll:fire()
  assert(#h.pending == 0)
  h.event("systemDidWake")
  h.cycle(COLLAPSED)
  assert(h.moves() == "move-node-to-workspace 1 --window-id 11\nmove-node-to-workspace 7 --window-id 12")
  assert(h.module.status().restoredWindows == 2)
  h.module.stop()
end)

test("late re-detection is restored, then manual moves are accepted", function()
  local h = harness()
  h.finish(BEFORE)
  h.event("screensDidSleep")
  h.event("screensDidWake")
  h.cycle(BEFORE)
  h.module.poll:fire()
  assert(#h.pending == 0, "polling must not overwrite the sleep snapshot")
  h.cycle(COLLAPSED)
  for _ = 3, 6 do h.cycle(BEFORE) end
  assert(not h.module.status().recovering)
  h.module.poll:fire()
  local manuallyMoved = "11|9|100|com.microsoft.VSCode\n12|7|100|com.microsoft.VSCode\n"
  h.finish(manuallyMoved)
  h.event("systemWillSleep")
  h.event("systemDidWake")
  h.cycle(COLLAPSED)
  assert(h.moves():find("move-node-to-workspace 9 --window-id 11", 1, true))
  h.module.stop()
end)

test("duplicate sleep/lock notifications keep the last healthy snapshot", function()
  local h = harness()
  h.finish(BEFORE)
  h.module.poll:fire()
  local staleTask = h.pending[1]
  h.event("screensDidLock")
  assert(staleTask.terminated)
  h.finish(COLLAPSED) -- A cancelled pre-sleep scan finishes after suspension.
  h.event("screensDidSleep")
  h.event("systemWillSleep")
  h.event("systemDidWake")
  h.event("screensDidWake")
  assert(not h.module.retry, "do not restore while the screen is still locked")
  h.event("screensDidUnlock")
  h.cycle(COLLAPSED)
  assert(h.module.status().restoredWindows == 2)
  h.module.stop()
end)

test("failed, empty, and malformed scans never erase the snapshot", function()
  local h = harness()
  h.finish(BEFORE)
  for _, output in ipairs({ "", "invalid output" }) do
    h.module.poll:fire()
    h.finish(output)
    assert(h.module.status().trackedWindows == 2)
  end
  h.module.poll:fire()
  h.finish("", 1)
  h.event("systemWillSleep")
  h.event("systemDidWake")
  h.cycle("", 1)
  h.cycle(COLLAPSED)
  assert(h.module.status().restoredWindows == 2)
  h.module.stop()
end)

test("utility, new, closed, and recycled windows are excluded", function()
  local h = harness()
  h.finish(BEFORE .. "13|2|101|com.electron.aqua-voice\n14|3|102|com.raycast.macos\n")
  assert(h.module.status().trackedWindows == 2)
  h.event("systemWillSleep")
  h.event("systemDidWake")
  h.cycle("11|4|999|com.microsoft.VSCode\n13|4|101|com.electron.aqua-voice\n"
    .. "14|4|102|com.raycast.macos\n15|4|103|new.app\n")
  assert(h.moves() == "")
  h.module.stop()
end)

test("a second sleep cancels recovery without replacing saved assignments", function()
  local h = harness()
  h.finish(BEFORE)
  h.event("systemWillSleep")
  h.event("systemDidWake")
  h.module.retry:fire()
  h.event("systemWillSleep")
  h.finish(COLLAPSED)
  assert(not h.module.retry)
  h.event("systemDidWake")
  h.cycle(COLLAPSED)
  assert(h.module.status().restoredWindows == 2)
  h.module.stop()
end)

test("hung CLI calls time out and do not accumulate processes", function()
  local h = harness()
  local task = h.pending[1]
  for _ = 1, 5 do h.module.poll:fire() end
  assert(#h.pending == 1)
  h.module.timeout:fire()
  assert(task.terminated and h.module.task == nil)
  h.finish(BEFORE) -- A timed-out task must not update the snapshot.
  assert(h.module.status().trackedWindows == 0)
  h.module.poll:fire()
  h.finish(BEFORE)
  assert(h.module.status().trackedWindows == 2)
  h.module.stop()
  assert(not h.module.status().enabled)
end)

return string.format("PASS: %d AeroSpace workspace recovery tests", tests)
