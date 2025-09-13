#!/bin/bash

# Tailscale Status Plugin

TAILSCALE_CMD="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

# Check if Tailscale is installed
if [ ! -f "$TAILSCALE_CMD" ]; then
    # Tailscale not installed
    BG_COLOR=0xff2d3748  # Dark grey
    ICON_COLOR=0xff666666 # Grey icon
    sketchybar --set tailscale \
      background.color=$BG_COLOR \
      icon.color=$ICON_COLOR
    exit 0
fi

# Get Tailscale status
STATUS=$($TAILSCALE_CMD status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo "Unknown")

# Set colors based on status
case "$STATUS" in
    "Running")
        # Connected - Green background, black icon
        BG_COLOR=0xff50fa7b
        ICON_COLOR=0xff000000
        ;;
    "Stopped"|"NeedsLogin")
        # Disconnected - Dark grey background, white icon
        BG_COLOR=0xff2d3748
        ICON_COLOR=0xffffffff
        ;;
    "Starting"|"NoState")
        # Connecting - Yellow background, black icon
        BG_COLOR=0xfff1fa8c
        ICON_COLOR=0xff000000
        ;;
    *)
        # Error/Unknown - Red background, white icon
        BG_COLOR=0xffff5555
        ICON_COLOR=0xffffffff
        ;;
esac

# Update SketchyBar item
sketchybar --set tailscale \
  background.color=$BG_COLOR \
  icon.color=$ICON_COLOR