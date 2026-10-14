#!/bin/sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
CODEX_DATA_DIR="${CODEX_HOME:-$HOME/.codex}"

# shellcheck source=/dev/null
. "$CONFIG_DIR/colors.sh"

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

circle_icon() {
    percentage="$1"

    if [ "$percentage" -le 0 ]; then
        printf '○'
    elif [ "$percentage" -le 12 ]; then
        printf '󰪞'
    elif [ "$percentage" -le 25 ]; then
        printf '󰪟'
    elif [ "$percentage" -le 37 ]; then
        printf '󰪠'
    elif [ "$percentage" -le 50 ]; then
        printf '󰪡'
    elif [ "$percentage" -le 62 ]; then
        printf '󰪢'
    elif [ "$percentage" -le 75 ]; then
        printf '󰪣'
    elif [ "$percentage" -le 87 ]; then
        printf '󰪤'
    else
        printf '󰪥'
    fi
}

meter_color() {
    percentage="$1"

    if [ "$percentage" -le 25 ]; then
        printf '%s' "$RED_COLOR"
    elif [ "$percentage" -le 50 ]; then
        printf '%s' "$YELLOW_COLOR"
    else
        printf '%s' "$GREEN_COLOR"
    fi
}

window_label() {
    minutes="$1"

    case "$minutes" in
        300) printf '5H' ;;
        10080) printf 'WEEKLY' ;;
        *)
            if [ "$minutes" -ge 1440 ]; then
                printf '%sD' "$((minutes / 1440))"
            else
                printf '%sH' "$((minutes / 60))"
            fi
            ;;
    esac
}

latest_record="$({
    current_day="$(date '+%Y/%m/%d')"
    previous_day="$(date -v-1d '+%Y/%m/%d')"

    for session_file in $(
        /bin/ls -t \
            "$CODEX_DATA_DIR/sessions/$current_day"/*.jsonl \
            "$CODEX_DATA_DIR/sessions/$previous_day"/*.jsonl \
            2>/dev/null | head -n 8
    ); do
        tail -n 160 "$session_file" 2>/dev/null
    done
} | jq -Rr '
    fromjson?
    | select(
        .payload.rate_limits?.limit_id == "codex"
        and .payload.rate_limits.primary.used_percent? != null
    )
    | [
        .timestamp,
        (.payload.rate_limits.primary.used_percent | floor),
        (.payload.rate_limits.primary.window_minutes // 0),
        (.payload.rate_limits.primary.resets_at // 0),
        (.payload.rate_limits.secondary.used_percent // -1 | floor),
        (.payload.rate_limits.secondary.window_minutes // 0),
        (.payload.rate_limits.secondary.resets_at // 0)
    ]
    | map(tostring)
    | join("|")
' 2>/dev/null | sort | tail -n 1)"

if [ -z "$latest_record" ]; then
    sketchybar --set "$NAME" icon="○" icon.color="$STATUS_ICON_COLOR" label="--%" \
               --set codex.usage.primary drawing=on icon="○" icon.color="$MUTED_COLOR" label="NO USAGE SNAPSHOT" \
               --set codex.usage.secondary drawing=off \
               --set codex.usage.reset label="Run Codex to refresh"
else
    IFS='|' read -r snapshot_time primary_used primary_window primary_reset \
        secondary_used secondary_window secondary_reset <<EOF
$latest_record
EOF

    primary_remaining=$((100 - primary_used))
    [ "$primary_remaining" -lt 0 ] && primary_remaining=0
    primary_label="$(window_label "$primary_window")"
    primary_icon="$(circle_icon "$primary_remaining")"
    primary_color="$(meter_color "$primary_remaining")"

    selected_remaining="$primary_remaining"
    selected_icon="$primary_icon"
    selected_color="$primary_color"
    selected_reset="$primary_reset"

    sketchybar --set codex.usage.primary \
        drawing=on \
        icon="$primary_icon" \
        icon.color="$primary_color" \
        label="$primary_label · $primary_remaining% LEFT"

    if [ "$secondary_used" -ge 0 ] && [ "$secondary_window" -gt 0 ]; then
        secondary_remaining=$((100 - secondary_used))
        [ "$secondary_remaining" -lt 0 ] && secondary_remaining=0
        secondary_label="$(window_label "$secondary_window")"
        secondary_icon="$(circle_icon "$secondary_remaining")"
        secondary_color="$(meter_color "$secondary_remaining")"

        sketchybar --set codex.usage.secondary \
            drawing=on \
            icon="$secondary_icon" \
            icon.color="$secondary_color" \
            label="$secondary_label · $secondary_remaining% LEFT"

        if [ "$secondary_remaining" -lt "$selected_remaining" ]; then
            selected_remaining="$secondary_remaining"
            selected_icon="$secondary_icon"
            selected_color="$secondary_color"
            selected_reset="$secondary_reset"
        fi
    else
        sketchybar --set codex.usage.secondary drawing=off
    fi

    if [ "$selected_reset" -gt 0 ]; then
        reset_label="RESETS $(date -r "$selected_reset" '+%a %m/%d %H:%M' | tr '[:lower:]' '[:upper:]')"
    else
        reset_label="RESET UNAVAILABLE"
    fi

    sketchybar --set "$NAME" \
        icon="$selected_icon" \
        icon.color="$STATUS_ICON_COLOR" \
        label="$selected_remaining%" \
        label.color="$selected_color" \
        --set codex.usage.reset label="$reset_label"
fi
