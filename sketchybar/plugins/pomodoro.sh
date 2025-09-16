#!/bin/bash

# Load configuration
CONFIG_FILE="$CONFIG_DIR/pomodoro.conf"
source "$CONFIG_FILE"

STATE_FILE="/tmp/sketchybar_pomodoro_state"
TIME_FILE="/tmp/sketchybar_pomodoro_time"
LAST_ACTIVITY_FILE="/tmp/sketchybar_pomodoro_last_activity"
HIDE_TIMEOUT=15  # 15 seconds for testing (was 600 for 10 minutes)

# Initialize state if not exists
if [ ! -f "$STATE_FILE" ]; then
    echo "stopped:work" > "$STATE_FILE"
fi

# Read current state
STATE=$(cat "$STATE_FILE")
STATUS=$(echo "$STATE" | cut -d: -f1)  # stopped/running
MODE=$(echo "$STATE" | cut -d: -f2)    # work/break

# Function to update last activity timestamp
update_last_activity() {
    date +%s > "$LAST_ACTIVITY_FILE"
}

# Check if should auto-hide (10 minutes of inactivity while stopped)
check_auto_hide() {
    if [ "$STATUS" = "stopped" ] && [ -f "$LAST_ACTIVITY_FILE" ]; then
        LAST_ACTIVITY=$(cat "$LAST_ACTIVITY_FILE")
        CURRENT_TIME=$(date +%s)
        ELAPSED=$((CURRENT_TIME - LAST_ACTIVITY))

        if [ $ELAPSED -ge $HIDE_TIMEOUT ]; then
            # Reset to work mode and hide
            echo "stopped:work" > "$STATE_FILE"
            sketchybar --set pomodoro drawing=off
            rm -f "$LAST_ACTIVITY_FILE"
            exit 0
        fi
    fi
}

# Handle different click events
case "$SENDER" in
    "mouse.clicked")
        # Left click: start/stop timer
        sketchybar --set pomodoro drawing=on  # Ensure visibility on click

        # Stop any playing alarm sound
        pkill -f "afplay.*kitchen-timer-5sec.mp3" 2>/dev/null

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
            rm -f "$LAST_ACTIVITY_FILE"  # Clear activity timer when running
        else
            # Stop timer
            echo "stopped:$MODE" > "$STATE_FILE"
            rm -f "$TIME_FILE"
            update_last_activity  # Start tracking inactivity
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
        update_last_activity  # Track inactivity after mode change
        ;;
esac

# Update display based on current state
STATE=$(cat "$STATE_FILE")
STATUS=$(echo "$STATE" | cut -d: -f1)
MODE=$(echo "$STATE" | cut -d: -f2)

# Check for auto-hide condition
check_auto_hide

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
        # Timer finished - play alarm sound and transition to next mode
        if [ -f "$ALARM_SOUND" ]; then
            afplay "$ALARM_SOUND" &
        fi

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
        update_last_activity  # Track inactivity after timer finishes
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