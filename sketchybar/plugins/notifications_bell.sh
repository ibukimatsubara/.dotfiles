#!/bin/bash

# Simple notification count display
NOTIF_COUNT=$(lsappinfo info -only StatusLabel $(lsappinfo find LSDisplayName="Notification Center") | grep -o '"StatusLabel"="[0-9]*"' | grep -o '[0-9]*' | head -1 2>/dev/null)

if [ ! -z "$NOTIF_COUNT" ] && [ "$NOTIF_COUNT" -gt 0 ]; then
  # Has notifications - red color
  ICON="󰅸"  # Bell with notification
  COLOR=0xffff5555  # Red
  BG_COLOR=0x33ff5555  # Semi-transparent red
else
  # No notifications - white color  
  ICON="󰂚"  # Normal bell
  COLOR=0xffffffff  # White
  BG_COLOR=0x33ffffff  # Semi-transparent white
fi

sketchybar --set notifications_bell \
  icon="$ICON" \
  icon.color=$COLOR \
  background.color=$BG_COLOR