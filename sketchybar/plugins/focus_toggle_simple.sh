#!/bin/bash

# Check if any Focus Mode is active (simplified)
FOCUS_STATUS=$(shortcuts run "Get Current Focus" 2>/dev/null || echo "")
DND_STATUS=$(plutil -extract dnd-prefs.userPref.enabled raw /Users/$(whoami)/Library/Preferences/com.apple.ncprefs.plist 2>/dev/null)

if [ ! -z "$FOCUS_STATUS" ] && [ "$FOCUS_STATUS" != "null" ] && [ "$FOCUS_STATUS" != "" ]; then
  # Focus mode is ON - Purple
  ICON="󰖔"  # Crescent moon
  COLOR=0xffffffff  # White icon
  BG_COLOR=0xff9f7aea  # Purple background
elif [ "$DND_STATUS" = "1" ]; then
  # DND is ON - Purple
  ICON="󰖔"  # Crescent moon
  COLOR=0xffffffff  # White icon
  BG_COLOR=0xff9f7aea  # Purple background
else
  # Focus mode is OFF - Dark theme
  ICON="󰖔"  # Crescent moon
  COLOR=0xffffffff  # White icon
  BG_COLOR=0xff4a5568  # Dark gray background
fi

sketchybar --set focus_toggle \
  icon="$ICON" \
  icon.color=$COLOR \
  background.color=$BG_COLOR