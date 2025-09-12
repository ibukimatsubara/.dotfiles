#!/bin/bash

# Check if any Focus Mode is active (simplified)
FOCUS_STATUS=$(shortcuts run "Get Current Focus" 2>/dev/null || echo "")
DND_STATUS=$(plutil -extract dnd-prefs.userPref.enabled raw /Users/$(whoami)/Library/Preferences/com.apple.ncprefs.plist 2>/dev/null)

if [ ! -z "$FOCUS_STATUS" ] && [ "$FOCUS_STATUS" != "null" ] && [ "$FOCUS_STATUS" != "" ]; then
  # Focus mode is ON - Purple/Blue
  ICON="󰖔"  # Crescent moon
  COLOR=0xffbd93f9  # Purple
  BG_COLOR=0x33bd93f9  # Semi-transparent purple
elif [ "$DND_STATUS" = "1" ]; then
  # DND is ON - Purple
  ICON="󰖔"  # Crescent moon
  COLOR=0xffbd93f9  # Purple
  BG_COLOR=0x33bd93f9  # Semi-transparent purple
else
  # Focus mode is OFF - Gray
  ICON="󰖔"  # Crescent moon
  COLOR=0xff6272a4  # Gray
  BG_COLOR=0x226272a4  # Semi-transparent gray
fi

sketchybar --set focus_toggle \
  icon="$ICON" \
  icon.color=$COLOR \
  background.color=$BG_COLOR