#!/bin/bash

# Load configuration
CONFIG_FILE="$CONFIG_DIR/pomodoro.conf"
source "$CONFIG_FILE"

STATE_FILE="/tmp/sketchybar_pomodoro_state"
TIME_FILE="/tmp/sketchybar_pomodoro_time"

# Initialize state if not exists
if [ ! -f "$STATE_FILE" ]; then
    echo "stopped:work" > "$STATE_FILE"
fi

# Read current state
STATE=$(cat "$STATE_FILE")
STATUS=$(echo "$STATE" | cut -d: -f1)  # stopped/running
MODE=$(echo "$STATE" | cut -d: -f2)    # work/break

# Handle different click events
case "$SENDER" in
    "mouse.clicked")
        # Left click: start/stop timer
        if [ "$STATUS" = "stopped" ]; then
            # Start timer
            echo "running:$MODE" > "$STATE_FILE"
            case "$MODE" in
                "work")
                    echo "$WORK_DURATION" > "$TIME_FILE"
                    ;;
                "break")
                    echo "$BREAK_DURATION" > "$TIME_FILE"
                    ;;
            esac
        else
            # Stop timer
            echo "stopped:$MODE" > "$STATE_FILE"
            rm -f "$TIME_FILE"
        fi
        ;;
    "mouse.clicked.right")
        # Right click: toggle between work and break
        case "$MODE" in
            "work")
                NEW_MODE="break"
                ;;
            "break")
                NEW_MODE="work"
                ;;
            *)
                NEW_MODE="work"
                ;;
        esac
        echo "stopped:$NEW_MODE" > "$STATE_FILE"
        rm -f "$TIME_FILE"
        ;;
esac

# Update display based on current state
STATE=$(cat "$STATE_FILE")
STATUS=$(echo "$STATE" | cut -d: -f1)
MODE=$(echo "$STATE" | cut -d: -f2)

# Convert seconds to mm:ss format
format_time() {
    local total_seconds=$1
    local minutes=$((total_seconds / 60))
    local seconds=$((total_seconds % 60))
    printf "%02d:%02d" $minutes $seconds
}

# Set icon and colors based on mode
case "$MODE" in
    "work")
        ICON="$WORK_ICON"
        BG_COLOR="$WORK_BG_COLOR"
        ICON_COLOR="$WORK_ICON_COLOR"
        ;;
    "break")
        ICON="$BREAK_ICON"
        BG_COLOR="$BREAK_BG_COLOR"
        ICON_COLOR="$BREAK_ICON_COLOR"
        ;;
esac

if [ "$STATUS" = "running" ] && [ -f "$TIME_FILE" ]; then
    # Timer is running - show remaining time
    REMAINING=$(cat "$TIME_FILE")
    TIME_DISPLAY=$(format_time $REMAINING)
    DISPLAY="$ICON $TIME_DISPLAY"

    # Countdown logic (this would be handled by a separate timer process)
    if [ "$REMAINING" -gt 0 ]; then
        echo $((REMAINING - 1)) > "$TIME_FILE"
    else
        # Timer finished - automatically transition to next mode
        case "$MODE" in
            "work")
                NEXT_MODE="break"
                ;;
            "break")
                NEXT_MODE="work"
                ;;
        esac
        echo "stopped:$NEXT_MODE" > "$STATE_FILE"
        rm -f "$TIME_FILE"
    fi
else
    # Timer is stopped - show max time for current mode
    case "$MODE" in
        "work")
            MAX_TIME="$WORK_DURATION"
            ;;
        "break")
            MAX_TIME="$BREAK_DURATION"
            ;;
    esac
    TIME_DISPLAY=$(format_time $MAX_TIME)
    DISPLAY="$ICON $TIME_DISPLAY"
fi

# Update SketchyBar
sketchybar --set pomodoro \
    icon="$DISPLAY" \
    background.color="$BG_COLOR" \
    icon.color="$ICON_COLOR"