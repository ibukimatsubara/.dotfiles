#!/bin/bash

# Simple toggle action
FOCUS_STATUS=$(shortcuts run "Get Current Focus" 2>/dev/null || echo "")
DND_STATUS=$(plutil -extract dnd-prefs.userPref.enabled raw /Users/$(whoami)/Library/Preferences/com.apple.ncprefs.plist 2>/dev/null)

if [ ! -z "$FOCUS_STATUS" ] && [ "$FOCUS_STATUS" != "null" ] && [ "$FOCUS_STATUS" != "" ]; then
  # Focus mode is ON, turn it OFF
  shortcuts run "Turn Off Focus" 2>/dev/null
  osascript -e 'display notification "Focus mode turned off" with title "Focus Toggle"' 2>/dev/null
elif [ "$DND_STATUS" = "1" ]; then
  # DND is ON, turn it OFF
  shortcuts run "Turn Off Do Not Disturb" 2>/dev/null
  osascript -e 'display notification "Do Not Disturb turned off" with title "Focus Toggle"' 2>/dev/null
else
  # No focus mode active, turn ON Do Not Disturb
  shortcuts run "Turn On Do Not Disturb" 2>/dev/null
  osascript -e 'display notification "Do Not Disturb turned on" with title "Focus Toggle"' 2>/dev/null
fi

# Update the display
sketchybar --trigger focus_changed