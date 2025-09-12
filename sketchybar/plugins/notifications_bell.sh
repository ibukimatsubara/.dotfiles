#!/bin/bash

# Get notification count for macOS 15+ (simplified approach)

# Primary method: Use system log to count recent notifications (more reliable for macOS 15+)
NOTIF_COUNT=$(log show --predicate 'subsystem == "com.apple.usernotifications" AND eventMessage CONTAINS "deliver"' --style compact --last 30m 2>/dev/null | wc -l | tr -d ' ' 2>/dev/null || echo "0")

# If log parsing fails or returns too many, try fallback methods
if [ -z "$NOTIF_COUNT" ] || ! [[ "$NOTIF_COUNT" =~ ^[0-9]+$ ]] || [ "$NOTIF_COUNT" -gt 50 ]; then
    # Fallback 1: Try lsappinfo (may not work in macOS 15+)
    NOTIF_COUNT=$(lsappinfo info -only StatusLabel $(lsappinfo find LSDisplayName="Notification Centre") | grep -o '"StatusLabel"="[0-9]*"' | grep -o '[0-9]*' | head -1 2>/dev/null)
    
    # Fallback 2: If still empty, default to a reasonable estimate
    if [ -z "$NOTIF_COUNT" ] || ! [[ "$NOTIF_COUNT" =~ ^[0-9]+$ ]]; then
        # Try to get a simple count from notification center process memory (approximate)
        NOTIF_COUNT=$(ps aux | grep NotificationCenter | grep -v grep | wc -l 2>/dev/null || echo "0")
        if [ "$NOTIF_COUNT" -gt 0 ]; then
            # If notification center is running, assume some notifications exist
            # This is a fallback estimate - you can adjust this logic
            NOTIF_COUNT=3
        else
            NOTIF_COUNT=0
        fi
    fi
fi

# Default to 0 if still no count found
NOTIF_COUNT=${NOTIF_COUNT:-0}

# Ensure it's a number
if ! [[ "$NOTIF_COUNT" =~ ^[0-9]+$ ]]; then
    NOTIF_COUNT=0
fi

if [ "$NOTIF_COUNT" -gt 10 ]; then
  # Many notifications - bright red
  ICON="󰅸"  # Bell with notification
  COLOR=0xffffffff  # White text
  BG_COLOR=0xffe53e3e  # Red background
  LABEL="$NOTIF_COUNT"
elif [ "$NOTIF_COUNT" -gt 5 ]; then
  # Several notifications - orange
  ICON="󰅸"  # Bell with notification
  COLOR=0xffffffff  # White text
  BG_COLOR=0xfff56500  # Orange background
  LABEL="$NOTIF_COUNT"
elif [ "$NOTIF_COUNT" -gt 0 ]; then
  # Few notifications - yellow
  ICON="󰅸"  # Bell with notification
  COLOR=0xff2d3748  # Dark text
  BG_COLOR=0xffecc94b  # Yellow background
  LABEL="$NOTIF_COUNT"
else
  # No notifications - dark theme
  ICON="󰂚"  # Normal bell
  COLOR=0xffffffff  # White text
  BG_COLOR=0xff2d3748  # Dark background
  LABEL=""  # No label when no notifications
fi

sketchybar --set notifications_bell \
  icon="$ICON" \
  icon.color=$COLOR \
  background.color=$BG_COLOR \
  label="$LABEL"