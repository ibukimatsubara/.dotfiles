#!/bin/sh

volume="${INFO:-}"
case "$volume" in
    ''|*[!0-9]*) volume="$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)" ;;
esac

case "$volume" in
    100|[6-9][0-9]) icon="󰕾" ;;
    [3-5][0-9]) icon="󰖀" ;;
    [1-9]|[1-2][0-9]) icon="󰕿" ;;
    *) icon="󰖁" ;;
esac

sketchybar --set "$NAME" icon="$icon" label="${volume:-0}%"
