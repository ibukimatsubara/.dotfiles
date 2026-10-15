-- 実行: lua scripts/test-ghostty-navigation.lua
local repo = arg[0]:match("^(.*)/scripts/[^/]+$") or "."
local bundle, title, role, subrole = "com.mitchellh.ghostty", "~/project", "AXTextArea", "AXStandardWindow"
local callback, launched, running, canStart = nil, {}, {}, true
local app = {
  bundleID = function() return bundle end,
  focusedWindow = function()
    return { id = function() return 42 end, title = function() return title end,
      subrole = function() return subrole end }
  end,
}
hs = {
  fs = { attributes = function() return { mode = "file" } end },
  application = { frontmostApplication = function() return app end },
  axuielement = { applicationElement = function()
    return { attributeValue = function()
      return { attributeValue = function() return role end }
    end }
  end },
  keycodes = { map = { [4] = "h", [38] = "j", [40] = "k", [37] = "l",
    [32] = "u", [34] = "i", [48] = "tab", [0] = "a" } },
  eventtap = {
    event = { types = { keyDown = 10 } },
    new = function(_, fn)
      callback = fn
      return { start = function(self) return self end, isEnabled = function() return true end }
    end,
  },
  task = { new = function(path, finished, args)
    local task = { start = function(self)
      if not canStart then return nil end
      assert(path == "/opt/homebrew/bin/aerospace")
      table.insert(launched, table.concat(args, " "))
      table.insert(running, { task = self, finished = finished })
      return self
    end }
    return task
  end },
}
local modules, accessed = hs, {}
hs = setmetatable({}, { __index = function(_, name)
  accessed[name] = true
  return modules[name]
end })
local navigation = dofile(repo .. "/hammerspoon/ghostty_navigation.lua")
for _, name in ipairs({ "application", "axuielement", "keycodes", "task" }) do
  assert(accessed[name], "module must be loaded before the first keypress: " .. name)
end
accessed = {}
local function key(code, flags)
  return callback({ getKeyCode = function() return code end,
    getFlags = function() return flags or { ctrl = true } end })
end
for _, code in ipairs({ 4, 38, 40, 37, 32, 34 }) do assert(key(code)) end
assert(next(accessed) == nil, "keypress must not trigger initial module loading")
assert(table.concat(launched, ",") == "focus --ignore-floating --wrap-around left,focus --ignore-floating --wrap-around down,focus --ignore-floating --wrap-around up,focus --ignore-floating --wrap-around right,workspace --wrap-around prev,workspace --wrap-around next")
for _, entry in ipairs(running) do
  assert(navigation.tasks[entry.task])
  entry.finished()
  assert(not navigation.tasks[entry.task])
end
assert(navigation.status().route == "aerospace")

title = "[tmux] project:0 ~/project"
for _, code in ipairs({ 4, 38, 40, 37 }) do assert(key(code)) end
for _, code in ipairs({ 32, 34 }) do assert(not key(code)) end
assert(navigation.status().route == "aerospace")
assert(navigation.status().workspaceRoute == "tmux")
-- Claude's title updates must not change directional routing inside tmux.
title = "[tmux] project:0 ✳ Claude Code"
assert(key(4))
title = "✳ Claude Code"
assert(key(37))
title = "~/project"
bundle = "com.microsoft.VSCode"
for _, code in ipairs({ 4, 32, 34 }) do assert(not key(code)) end
bundle = "com.mitchellh.ghostty"
for _, modifier in ipairs({ "cmd", "alt", "shift", "fn" }) do
  for _, code in ipairs({ 4, 32, 34 }) do
    assert(not key(code, { ctrl = true, [modifier] = true }))
  end
end
assert(not key(4, {}))
assert(not key(0))
assert(not key(48)) -- TabはCtrl+iの別名として奪わない。
role = "AXTextField"
assert(not key(4))
role = "AXTextArea"
subrole = "AXDialog"
assert(not key(4))
subrole = "AXStandardWindow"
title = ""
assert(not key(4))
title = "~/project"
canStart = false
assert(not key(4))
for _, entry in ipairs(running) do entry.finished() end
assert(next(navigation.tasks) == nil)
assert(#launched == 12, "passthrough must not change window focus")
local config = assert(io.open(repo .. "/tmux/tmux.conf")):read("*a")
assert(config:find("set -g set-titles on", 1, true))
assert(config:find("set -g set-titles-string '[tmux] ", 1, true))
print("PASS: TUI/tmux direction routing, tmux workspace passthrough, wrapping, Tab, app/dialog scope, modifiers, and task cleanup")
