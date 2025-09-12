#!/bin/bash

# Dynamic notification display with multiple states
NOTIF_COUNT=$(lsappinfo info -only StatusLabel $(lsappinfo find LSDisplayName="Notification Center") | grep -o '"StatusLabel"="[0-9]*"' | grep -o '[0-9]*' | head -1 2>/dev/null)

# Default to 0 if no count found
NOTIF_COUNT=${NOTIF_COUNT:-0}

if [ "$NOTIF_COUNT" -gt 10 ]; then
  # Many notifications - bright red
  ICON="󰅸"  # Bell with notification
  COLOR=0xffff5555  # Bright red
  BG_COLOR=0x44ff5555  # More opaque red
elif [ "$NOTIF_COUNT" -gt 5 ]; then
  # Several notifications - orange
  ICON="󰅸"  # Bell with notification
  COLOR=0xffffb86c  # Orange
  BG_COLOR=0x33ffb86c  # Semi-transparent orange
elif [ "$NOTIF_COUNT" -gt 0 ]; then
  # Few notifications - yellow
  ICON="󰅸"  # Bell with notification
  COLOR=0xfff1fa8c  # Yellow
  BG_COLOR=0x33f1fa8c  # Semi-transparent yellow
else
  # No notifications - subtle white
  ICON="󰂚"  # Normal bell
  COLOR=0xaaffffff  # Dimmed white
  BG_COLOR=0x22ffffff  # Very subtle white
fi

sketchybar --set notifications_bell \
  icon="$ICON" \
  icon.color=$COLOR \
  background.color=$BG_COLOR