require("hs.ipc")

-- 次のログインでも Ghostty のキー振り分けを利用できるようにする。
hs.autoLaunch(true)

package.path = package.path .. ";" .. os.getenv("HOME") .. "/.dotfiles/hammerspoon/?.lua"

-- Ghostty 休憩タイマー (30分作業 / 3分休憩、⌘Pで手動開始)
breaktimer = require("break_timer")

-- Ghostty の Ctrl+h/j/k/l は TUI・tmux 内でも AeroSpace のフォーカス移動に使う。
ghosttynavigation = require("ghostty_navigation")

-- Rotate the active theme's wallpapers, with legacy screen variants as fallback.
wallpaper = require("wallpaper").start()

-- Ctrl+Option+Cmd+T: pick a desktop theme; N: next theme; W: next wallpaper.
desktoptheme = require("desktop_theme").start()

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
