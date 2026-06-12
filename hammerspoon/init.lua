require("hs.ipc")

package.path = package.path .. ";" .. os.getenv("HOME") .. "/.dotfiles/hammerspoon/?.lua"

-- Ghostty 強制休憩タイマー (30分 → 星空フェード → 3分休憩)
breaktimer = require("break_timer")

-- Mic priority (higher = preferred)
local micPriority = {
  ["DJI MIC MINI"]        = 4,
  ["USB PnP Audio Device"] = 3,
  ["MacBook Air Microphone"] = 2,
  ["WF-1000XM5"]          = 1,
}

local function selectBestMic()
  local best = nil
  local bestScore = 0
  for _, dev in ipairs(hs.audiodevice.allInputDevices()) do
    local score = micPriority[dev:name()] or 0
    if score > bestScore then
      best = dev
      bestScore = score
    end
  end
  if best and best:name() ~= hs.audiodevice.defaultInputDevice():name() then
    best:setDefaultInputDevice()
    hs.notify.show("マイク切替", "", best:name())
  end
end

hs.audiodevice.watcher.setCallback(function(event)
  if event == "dev#" then
    selectBestMic()
  end
end)
hs.audiodevice.watcher:start()

-- Set best mic on launch too
selectBestMic()
