#!/bin/bash

if [ "$NAME" = "notifications" ]; then
  # Check for Focus/DND status using shortcuts
  FOCUS_STATUS=$(shortcuts run "Get Current Focus" 2>/dev/null || echo "")
  DND_STATUS=$(plutil -extract dnd-prefs.userPref.enabled raw /Users/$(whoami)/Library/Preferences/com.apple.ncprefs.plist 2>/dev/null)
  
  # Check if any focus mode is active or DND is on
  if [ ! -z "$FOCUS_STATUS" ] && [ "$FOCUS_STATUS" != "null" ] && [ "$FOCUS_STATUS" != "" ]; then
    # Focus mode is active
    case "$FOCUS_STATUS" in
      *"Work"* | *"仕事"*)
        ICON="󰌌"  # Work icon
        COLOR=0xff50fa7b
        LABEL="Work"
        ;;
      *"Personal"* | *"プライベート"*)
        ICON="󰋜"  # Personal icon  
        COLOR=0xff8be9fd
        LABEL="Personal"
        ;;
      *"Sleep"* | *"睡眠"*)
        ICON="󰒲"  # Sleep icon
        COLOR=0xff6272a4
        LABEL="Sleep"
        ;;
      *"Do Not Disturb"* | *"おやすみモード"*)
        ICON="󰂛"  # Moon icon
        COLOR=0xffbd93f9
        LABEL="DND"
        ;;
      *)
        ICON="󰔡"  # Focus icon
        COLOR=0xfff1fa8c
        LABEL="Focus"
        ;;
    esac
  elif [ "$DND_STATUS" = "1" ]; then
    ICON="󰂛"  # Moon icon for DND
    COLOR=0xffbd93f9
    LABEL="DND"
  else
    # Count unread notifications (approximation)
    NOTIF_COUNT=$(lsappinfo info -only StatusLabel $(lsappinfo find LSDisplayName="Notification Center") | grep -o '"StatusLabel"="[0-9]*"' | grep -o '[0-9]*' | head -1)
    
    if [ -z "$NOTIF_COUNT" ] || [ "$NOTIF_COUNT" -eq 0 ]; then
      ICON="󰂚"  # Bell icon
      COLOR=0xffffffff
      LABEL=""
    else
      ICON="󰅸"  # Bell with notification
      COLOR=0xffff5555
      LABEL="$NOTIF_COUNT"
    fi
  fi
  
  sketchybar --set notifications \
    icon="$ICON" \
    icon.color=$COLOR \
    label="$LABEL"
fi