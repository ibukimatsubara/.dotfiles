#!/bin/sh

status_path="${TMUX_BREAK_TIMER_STATUS_FILE:-$HOME/.cache/ghostty-break/tmux_status.tsv}"

# shellcheck source=/dev/null
. "$CONFIG_DIR/colors.sh"

if [ ! -r "$status_path" ]; then
    sketchybar --set "$NAME" icon="" label="OFF"
    exit 0
fi

IFS="$(printf '\t')" read -r enabled state started duration < "$status_path"

case "$enabled:$state" in
    false:*)
        icon=""
        label="OFF"
        color="$MUTED_COLOR"
        ;;
    true:waiting)
        icon=""
        label="READY"
        color="$GREEN_COLOR"
        ;;
    true:work|true:snoozed|true:fading|true:break)
        case "$started:$duration" in
            *[!0-9:]*|:*|*:)
                remaining=0
                ;;
            *)
                remaining=$((duration - ($(date +%s) - started)))
                [ "$remaining" -lt 0 ] && remaining=0
                ;;
        esac

        minutes=$((remaining / 60))
        seconds=$((remaining % 60))
        label="$(printf '%02d:%02d' "$minutes" "$seconds")"

        case "$state" in
            work) icon="󰔛"; color="$GREEN_COLOR" ;;
            snoozed) icon="󰒲"; color="$YELLOW_COLOR" ;;
            fading) icon=""; color="$BLUE_COLOR" ;;
            break) icon=""; color="$MAUVE_COLOR" ;;
        esac
        ;;
    *)
        icon=""
        label="OFF"
        color="$MUTED_COLOR"
        ;;
esac

sketchybar --set "$NAME" icon="$icon" icon.color="$color" label="$label" label.color="$color"
