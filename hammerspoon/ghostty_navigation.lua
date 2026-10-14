-- Ghostty の tmux 外だけ Ctrl+h/j/k/l で AeroSpace のタイルへ移動し、端で循環する。
-- Ctrl+u/i は Ctrl+y/o と同じ前・次のワークスペース移動。
-- tmux はタイトル先頭の [tmux] で識別し、元のキー入力をそのまま通す。
local M = { tasks = {} }
-- 最初のキー入力を処理する間に拡張の初回ロードが走らないようにする。
local application = hs.application
local axuielement = hs.axuielement
local keycodes = hs.keycodes
local taskModule = hs.task
local DIRECTIONS = { h = "left", j = "down", k = "up", l = "right" }
local WORKSPACES = { u = "prev", i = "next" }
local TMUX_TITLE_PREFIX = "[tmux] "
local aerospacePath
for _, path in ipairs({ "/opt/homebrew/bin/aerospace", "/usr/local/bin/aerospace" }) do
  local attr = hs.fs.attributes(path)
  if attr and attr.mode == "file" then
    aerospacePath = path
    break
  end
end

local function context()
  local app = application.frontmostApplication()
  if not app or app:bundleID() ~= "com.mitchellh.ghostty" then return nil end
  local window = app:focusedWindow()
  if not window or window:subrole() ~= "AXStandardWindow" then return nil end
  local element = axuielement.applicationElement(app):attributeValue("AXFocusedUIElement")
  if not element or element:attributeValue("AXRole") ~= "AXTextArea" then return nil end
  local title = window:title()
  if not title or title == "" then return nil end
  return { window = window:id(), tmux = title:sub(1, #TMUX_TITLE_PREFIX) == TMUX_TITLE_PREFIX }
end

M.tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  local flags = event:getFlags()
  if not flags.ctrl or flags.cmd or flags.alt or flags.shift or flags.fn then return false end
  local key = keycodes.map[event:getKeyCode()]
  local direction, workspace = DIRECTIONS[key], WORKSPACES[key]
  if not (direction or workspace) or not aerospacePath then return false end
  local current = context()
  if not current or current.tmux then return false end

  -- 外部コマンドは非同期で実行し、イベントタップを待たせない。
  local args = workspace and { "workspace", "--wrap-around", workspace }
      or { "focus", "--ignore-floating", "--wrap-around", direction }
  local task
  task = taskModule.new(aerospacePath, function() M.tasks[task] = nil end, args)
  if not task then return false end
  M.tasks[task] = true
  if not task:start() then
    M.tasks[task] = nil
    return false
  end
  return true
end):start()

function M.status()
  local current = context()
  return {
    enabled = M.tap:isEnabled() and aerospacePath ~= nil,
    window = current and current.window,
    route = current and (current.tmux and "tmux" or "aerospace") or "passthrough",
  }
end

return M
