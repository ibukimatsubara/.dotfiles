#!/bin/sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
# Written by claude/statusline-command.sh from the statusline rate_limits input.
SNAPSHOT_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/claude-code/rate-limits.json"

# shellcheck source=/dev/null
. "$CONFIG_DIR/colors.sh"
# shellcheck source=/dev/null
. "$CONFIG_DIR/plugins/usage_meter.sh"

case "$SENDER" in
    mouse.clicked)
        sketchybar --set "$NAME" popup.drawing=toggle
        exit 0
        ;;
    mouse.exited.global)
        sketchybar --set "$NAME" popup.drawing=off
        exit 0
        ;;
esac

# Prints "remaining|resets_at"; a window whose reset time has passed is full again.
window_remaining() {
    used="$1"
    resets_at="$2"

    if [ "$resets_at" -gt 0 ] && [ "$resets_at" -le "$now" ]; then
        printf '100|0'
        return
    fi

    remaining=$((100 - used))
    [ "$remaining" -lt 0 ] && remaining=0
    printf '%s|%s' "$remaining" "$resets_at"
}

set_window_row() {
    item="$1"
    label="$2"
    used="$3"
    resets_at="$4"

    if [ "$used" -lt 0 ]; then
        sketchybar --set "$item" drawing=off
        return
    fi

    IFS='|' read -r remaining _ <<EOF
$(window_remaining "$used" "$resets_at")
EOF
    sketchybar --set "$item" \
        drawing=on \
        icon="$(circle_icon "$remaining")" \
        icon.color="$(meter_color "$remaining")" \
        label="$label · $remaining% LEFT"
}

now="$(date '+%s')"
snapshot="$(jq -r '
    [
        (.captured_at // 0),
        (.rate_limits.seven_day.used_percentage // -1 | floor),
        (.rate_limits.seven_day.resets_at // 0 | floor),
        (.rate_limits.five_hour.used_percentage // -1 | floor),
        (.rate_limits.five_hour.resets_at // 0 | floor)
    ]
    | map(tostring)
    | join("|")
' "$SNAPSHOT_FILE" 2>/dev/null)"

IFS='|' read -r captured_at weekly_used weekly_reset five_hour_used five_hour_reset <<EOF
$snapshot
EOF

if [ -z "$snapshot" ] || [ "${weekly_used:--1}" -lt 0 ]; then
    sketchybar --set "$NAME" icon="○" icon.color="$STATUS_ICON_COLOR" label="CC --%" label.color="$TEXT_COLOR" \
               --set claude.usage.weekly drawing=on icon="○" icon.color="$MUTED_COLOR" label="NO USAGE SNAPSHOT" \
               --set claude.usage.five_hour drawing=off \
               --set claude.usage.reset label="Run Claude Code to refresh" \
               --set claude.usage.source label="STATUSLINE SNAPSHOT"
    exit 0
fi

set_window_row claude.usage.five_hour 5H "$five_hour_used" "$five_hour_reset"
set_window_row claude.usage.weekly WEEKLY "$weekly_used" "$weekly_reset"

IFS='|' read -r weekly_remaining weekly_next_reset <<EOF
$(window_remaining "$weekly_used" "$weekly_reset")
EOF

if [ "$weekly_next_reset" -gt 0 ]; then
    reset_label="RESETS $(date -r "$weekly_next_reset" '+%a %m/%d %H:%M' | tr '[:lower:]' '[:upper:]')"
else
    reset_label="RESET SINCE LAST SNAPSHOT"
fi

if [ "$captured_at" -gt 0 ]; then
    source_label="SNAPSHOT $(date -r "$captured_at" '+%m/%d %H:%M')"
else
    source_label="STATUSLINE SNAPSHOT"
fi

sketchybar --set "$NAME" \
    icon="$(circle_icon "$weekly_remaining")" \
    icon.color="$STATUS_ICON_COLOR" \
    label="CC $weekly_remaining%" \
    label.color="$(meter_color "$weekly_remaining")" \
    --set claude.usage.reset label="$reset_label" \
    --set claude.usage.source label="$source_label"
