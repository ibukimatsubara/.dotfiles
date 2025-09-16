#!/bin/bash

# Tailscale Status Plugin with smart visibility

TAILSCALE_CMD="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
STATE_FILE="/tmp/sketchybar_tailscale_state"

# Check if Tailscale is installed
if [ ! -f "$TAILSCALE_CMD" ]; then
    # Tailscale not installed - hide
    sketchybar --set tailscale drawing=off
    exit 0
fi

# Get current Tailscale status
STATUS=$($TAILSCALE_CMD status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo "Unknown")

# Read previous state
PREV_STATUS=""
if [ -f "$STATE_FILE" ]; then
    PREV_STATUS=$(cat "$STATE_FILE")
fi

# Save current status
echo "$STATUS" > "$STATE_FILE"

# Auto-hide timer function
schedule_hide() {
    (sleep 60; sketchybar --set tailscale drawing=off) &
}

# Set colors and visibility based on status
case "$STATUS" in
    "Running")
        # Connected - hide when connected
        if [ "$PREV_STATUS" != "Running" ]; then
            # Status just changed to connected - show briefly then hide
            BG_COLOR=0xff50fa7b
            ICON_COLOR=0xff000000
            sketchybar --set tailscale \
                drawing=on \
                background.color=$BG_COLOR \
                icon.color=$ICON_COLOR
            schedule_hide
        else
            # Already connected - keep hidden
            sketchybar --set tailscale drawing=off
        fi
        ;;
    "Stopped"|"NeedsLogin")
        # Disconnected - show when disconnected
        if [ "$PREV_STATUS" != "$STATUS" ]; then
            # Status just changed to disconnected - show briefly then hide
            BG_COLOR=0xff2d3748
            ICON_COLOR=0xffffffff
            sketchybar --set tailscale \
                drawing=on \
                background.color=$BG_COLOR \
                icon.color=$ICON_COLOR
            schedule_hide
        else
            # Still disconnected - keep showing
            BG_COLOR=0xff2d3748
            ICON_COLOR=0xffffffff
            sketchybar --set tailscale \
                drawing=on \
                background.color=$BG_COLOR \
                icon.color=$ICON_COLOR
        fi
        ;;
    "Starting"|"NoState")
        # Connecting - show during transition
        BG_COLOR=0xfff1fa8c
        ICON_COLOR=0xff000000
        sketchybar --set tailscale \
            drawing=on \
            background.color=$BG_COLOR \
            icon.color=$ICON_COLOR
        ;;
    *)
        # Error/Unknown - show error state
        BG_COLOR=0xffff5555
        ICON_COLOR=0xffffffff
        sketchybar --set tailscale \
            drawing=on \
            background.color=$BG_COLOR \
            icon.color=$ICON_COLOR
        ;;
esac