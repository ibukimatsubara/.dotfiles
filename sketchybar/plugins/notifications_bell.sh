#!/bin/bash

# Dynamic notification display with multiple states
NOTIF_COUNT=$(lsappinfo info -only StatusLabel $(lsappinfo find LSDisplayName="Notification Center") | grep -o '"StatusLabel"="[0-9]*"' | grep -o '[0-9]*' | head -1 2>/dev/null)

# Default to 0 if no count found
NOTIF_COUNT=${NOTIF_COUNT:-0}

if [ "$NOTIF_COUNT" -gt 10 ]; then
  # Many notifications - bright red
  ICON="󰅸"  # Bell with notification
  COLOR=0xffffffff  # White text
  BG_COLOR=0xffe53e3e  # Red background
elif [ "$NOTIF_COUNT" -gt 5 ]; then
  # Several notifications - orange
  ICON="󰅸"  # Bell with notification
  COLOR=0xffffffff  # White text
  BG_COLOR=0xfff56500  # Orange background
elif [ "$NOTIF_COUNT" -gt 0 ]; then
  # Few notifications - yellow
  ICON="󰅸"  # Bell with notification
  COLOR=0xff2d3748  # Dark text
  BG_COLOR=0xffecc94b  # Yellow background
else
  # No notifications - dark theme
  ICON="󰂚"  # Normal bell
  COLOR=0xffffffff  # White text
  BG_COLOR=0xff2d3748  # Dark background
fi

sketchybar --set notifications_bell \
  icon="$ICON" \
  icon.color=$COLOR \
  background.color=$BG_COLOR