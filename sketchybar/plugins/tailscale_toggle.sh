#!/bin/bash

# Tailscale Toggle Plugin

TAILSCALE_CMD="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

# Check if Tailscale is installed
if [ ! -f "$TAILSCALE_CMD" ]; then
    # Try to open Tailscale app if CLI not available
    open -a "Tailscale" 2>/dev/null || \
    open "https://tailscale.com/download" 2>/dev/null
    exit 0
fi

# Get current status
STATUS=$($TAILSCALE_CMD status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo "Unknown")

# Toggle based on current status
case "$STATUS" in
    "Running")
        # Currently connected - disconnect
        $TAILSCALE_CMD down 2>/dev/null
        ;;
    "Stopped"|"NeedsLogin"|"NoState"|"Unknown")
        # Currently disconnected - connect
        $TAILSCALE_CMD up --accept-routes 2>/dev/null
        ;;
    "Starting")
        # Currently starting - try to force connection
        $TAILSCALE_CMD up --accept-routes 2>/dev/null
        ;;
    *)
        # Unknown state - try to connect
        $TAILSCALE_CMD up --accept-routes 2>/dev/null
        ;;
esac

# Wait a moment for state change to propagate
sleep 1

# Update the display immediately
if [ -f "$CONFIG_DIR/plugins/tailscale.sh" ]; then
    "$CONFIG_DIR/plugins/tailscale.sh"
fi