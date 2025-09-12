#!/bin/bash

# Focus mode toggle script
FOCUS_STATUS=$(shortcuts run "Get Current Focus" 2>/dev/null || echo "")

if [ ! -z "$FOCUS_STATUS" ] && [ "$FOCUS_STATUS" != "null" ] && [ "$FOCUS_STATUS" != "" ]; then
  # Focus mode is active, turn it off
  shortcuts run "Turn Off Focus" 2>/dev/null
  osascript -e 'display notification "Focus mode turned off" with title "SketchyBar"'
else
  # No focus mode active, show menu to select one
  CHOICE=$(osascript << 'EOF'
tell application "System Events"
    set focusModes to {"Work", "Personal", "Do Not Disturb", "Sleep", "Cancel"}
    set selectedMode to choose from list focusModes with title "Select Focus Mode" with prompt "Choose a focus mode:"
    if selectedMode is not false then
        return item 1 of selectedMode
    else
        return "Cancel"
    end if
end tell
EOF
)

  if [ "$CHOICE" != "Cancel" ] && [ ! -z "$CHOICE" ]; then
    case "$CHOICE" in
      "Work")
        shortcuts run "Turn On Work Focus" 2>/dev/null
        ;;
      "Personal")
        shortcuts run "Turn On Personal Focus" 2>/dev/null
        ;;
      "Do Not Disturb")
        shortcuts run "Turn On Do Not Disturb" 2>/dev/null
        ;;
      "Sleep")
        shortcuts run "Turn On Sleep Focus" 2>/dev/null
        ;;
    esac
    osascript -e "display notification \"$CHOICE mode activated\" with title \"SketchyBar\""
  fi
fi

# Update the bar
sketchybar --trigger notifications_update