#!/bin/sh

battery_state="$(pmset -g batt)"
percentage="$(printf '%s\n' "$battery_state" | sed -n 's/.*[[:space:]]\([0-9][0-9]*\)%.*/\1/p' | head -n 1)"

if [ -z "$percentage" ]; then
    exit 0
fi

case "$percentage" in
    9[0-9]|100) icon="" ;;
    [6-8][0-9]) icon="" ;;
    [3-5][0-9]) icon="" ;;
    [1-2][0-9]) icon="" ;;
    *) icon="" ;;
esac

# shellcheck source=/dev/null
. "$CONFIG_DIR/colors.sh"

color="$TEXT_COLOR"
if printf '%s\n' "$battery_state" | grep -q 'AC Power'; then
    icon=""
    color="$GREEN_COLOR"
elif [ "$percentage" -le 20 ]; then
    color="$RED_COLOR"
elif [ "$percentage" -le 40 ]; then
    color="$YELLOW_COLOR"
fi

sketchybar --set "$NAME" icon="$icon" icon.color="$color" label="${percentage}%"
