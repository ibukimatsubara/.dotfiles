-- A thin display frame with concave transitions at the bar and lower corners.
local M = {}
local STATE = os.getenv("HOME") .. "/.config/desktop-theme/current/theme.json"
local canvases = {}
local screenWatcher, spaceWatcher = nil, nil

local function clear()
  for _, canvas in ipairs(canvases) do canvas:delete() end
  canvases = {}
end

local function drawShape(frame, hex, transform, path)
  local canvas = hs.canvas.new(frame)
  -- SVG preserves sRGB; canvas fillColor uses calibrated RGB and leaves a seam.
  local svg = string.format(
    '<svg xmlns="http://www.w3.org/2000/svg" width="%g" height="%g">'
      .. '<path fill="#%s" fill-opacity="%g" transform="%s" d="%s"/></svg>',
    frame.w, frame.h, hex:sub(5), tonumber(hex:sub(3, 4), 16) / 255, transform, path)
  canvas:appendElements({ type = "image", frame = { x = 0, y = 0, w = frame.w, h = frame.h },
    image = hs.image.imageFromURL("data:image/svg+xml;base64," .. hs.base64.encode(svg)) })
  -- Lower window levels are constrained below the menu bar on notched displays.
  -- Keep display-edge decorations at their requested fullFrame coordinates.
  canvas:level(hs.canvas.windowLevels.mainMenu)
  canvas:behavior({ "canJoinAllSpaces", "stationary", "ignoresCycle" })
  canvas:clickActivating(false)
  canvas:canvasMouseEvents(false, false, false, false)
  canvas:show()
  table.insert(canvases, canvas)
end

function M.refresh(data)
  clear()
  if not data then data = hs.json.read(STATE) end
  local style = data and data.style or {}
  local radius = tonumber(style.BAR_INVERSE_RADIUS) or 0
  local topCorners = style.BAR_ATTACHED == 1 and radius > 0
  local bottomRadius = tonumber(style.SCREEN_BOTTOM_RADIUS) or 0
  local borderWidth = tonumber(style.SCREEN_BORDER_WIDTH) or 0
  if not topCorners and bottomRadius <= 0 and borderWidth <= 0 then return end

  local hex = data.colors.BAR_COLOR
  -- Fill the outer section's corner cutouts while leaving the middle gaps clear.
  local extension = style.BAR_SECTIONS == 1 and style.BAR_HEIGHT or 0
  local activeSpaces = hs.spaces.activeSpaces()
  for _, screen in ipairs(hs.screen.allScreens()) do
    local space = activeSpaces[screen:getUUID()]
    -- Match SketchyBar's default of hiding in native fullscreen Spaces.
    if not space or hs.spaces.spaceType(space) ~= "fullscreen" then
      local frame = screen:fullFrame()
      if borderWidth > 0 then
        for _, edge in ipairs({
          { x = frame.x, y = frame.y, w = frame.w, h = borderWidth },
          { x = frame.x, y = frame.y + frame.h - borderWidth, w = frame.w, h = borderWidth },
          { x = frame.x, y = frame.y + borderWidth, w = borderWidth, h = frame.h - 2 * borderWidth },
          { x = frame.x + frame.w - borderWidth, y = frame.y + borderWidth,
            w = borderWidth, h = frame.h - 2 * borderWidth },
        }) do
          drawShape(edge, data.colors.DARK_COLOR, "",
            string.format("M0 0H%gV%gH0Z", edge.w, edge.h))
        end
      end
      for _, right in ipairs({ false, true }) do
        if topCorners then
          drawShape({
            x = frame.x + (right and frame.w - borderWidth - radius or borderWidth),
            y = frame.y + style.BAR_HEIGHT - extension,
            w = radius, h = radius + extension,
          }, hex, right and string.format("translate(%g 0) scale(-1 1)", radius) or "",
            string.format("M0 0H%gV%gA%g %g 0 0 0 0 %gZ",
              radius, extension, radius, radius, radius + extension))
        end
        if bottomRadius > 0 then
          drawShape({
            x = frame.x + (right and frame.w - borderWidth - bottomRadius or borderWidth),
            y = frame.y + frame.h - borderWidth - bottomRadius,
            w = bottomRadius, h = bottomRadius,
          }, data.colors.DARK_COLOR,
            string.format("translate(%g %g) scale(%d -1)",
              right and bottomRadius or 0, bottomRadius, right and -1 or 1),
            string.format("M0 0H%gA%g %g 0 0 0 0 %gZ",
              bottomRadius, bottomRadius, bottomRadius, bottomRadius))
        end
      end
    end
  end
end

function M.stop()
  clear()
  if screenWatcher then screenWatcher:stop() end
  if spaceWatcher then spaceWatcher:stop() end
end

function M.start()
  M.stop()
  screenWatcher = hs.screen.watcher.new(function() M.refresh() end):start()
  spaceWatcher = hs.spaces.watcher.new(function() M.refresh() end):start()
  M.refresh()
  return M
end

return M
