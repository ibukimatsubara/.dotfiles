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

next_mode() {
    if [ "$1" = "work" ]; then
        echo "break"
    else
        echo "work"
    fi
}

set_timer_for_mode() {
    case "$1" in
        "work")
            echo "$WORK_DURATION"
            ;;
        "break")
            echo "$BREAK_DURATION"
            ;;
    esac
}

is_right_click() {
    case "${BUTTON:-}" in
        right|2|3)
            return 0
            ;;
    esac

    return 1
}

start_timer() {
    local mode="$1"

    if [ ! -f "$TIME_FILE" ]; then
        set_timer_for_mode "$mode" > "$TIME_FILE"
    fi

    echo "running:$mode" > "$STATE_FILE"
}

stop_timer() {
    local mode="$1"

    echo "stopped:$mode" > "$STATE_FILE"
}

skip_session() {
    local mode="$1"
    local status="$2"
    local next

    next=$(next_mode "$mode")

    if [ "$status" = "running" ]; then
        echo "running:$next" > "$STATE_FILE"
        set_timer_for_mode "$next" > "$TIME_FILE"
    else
        echo "stopped:$next" > "$STATE_FILE"
        rm -f "$TIME_FILE"
    fi
}

# Handle different click events
case "$SENDER" in
    "mouse.clicked")
        # Left click: start/stop timer
        # Stop any playing alarm sound
        pkill -f "afplay.*kitchen-timer-5sec.mp3" 2>/dev/null

        if is_right_click; then
            skip_session "$MODE" "$STATUS"
        else
            if [ "$STATUS" = "stopped" ]; then
                start_timer "$MODE"
            else
                stop_timer "$MODE"
            fi
        fi
        ;;
    "mouse.clicked.right")
        # Right click: skip to next mode
        skip_session "$MODE" "$STATUS"
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
        BORDER_COLOR="$WORK_BORDER_COLOR"
        ICON_COLOR="$WORK_ICON_COLOR"
        ;;
    "break")
        ICON="$BREAK_ICON"
        BG_COLOR="$BREAK_BG_COLOR"
        BORDER_COLOR="$BREAK_BORDER_COLOR"
        ICON_COLOR="$BREAK_ICON_COLOR"
        ;;
esac

if [ "$STATUS" = "running" ] && [ ! -f "$TIME_FILE" ]; then
    set_timer_for_mode "$MODE" > "$TIME_FILE"
fi

if [ -f "$TIME_FILE" ]; then
    REMAINING=$(cat "$TIME_FILE")
    TIME_DISPLAY=$(format_time "$REMAINING")
else
    MAX_TIME=$(set_timer_for_mode "$MODE")
    TIME_DISPLAY=$(format_time "$MAX_TIME")
fi

DISPLAY="$ICON $TIME_DISPLAY"

if [ "$STATUS" = "running" ] && [ -f "$TIME_FILE" ]; then
    if [ "$REMAINING" -gt 0 ]; then
        echo $((REMAINING - 1)) > "$TIME_FILE"
    else
        if [ -f "$ALARM_SOUND" ]; then
            afplay "$ALARM_SOUND" &
        fi

        NEXT_MODE=$(next_mode "$MODE")
        echo "stopped:$NEXT_MODE" > "$STATE_FILE"
        rm -f "$TIME_FILE"
    fi
fi

# Update SketchyBar
sketchybar --set pomodoro \
    icon="$DISPLAY" \
    background.color="$BG_COLOR" \
    background.border_color="$BORDER_COLOR" \
    background.border_width=2 \
    icon.color="$ICON_COLOR"
