#!/bin/sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

# shellcheck source=/dev/null
source "$CONFIG_DIR/colors.sh"

session_number="${NAME##*.}"
session_id="\$$session_number"

if ! command -v tmux >/dev/null 2>&1; then
    sketchybar --set "$NAME" drawing=off
    exit 0
fi

session_name="$(tmux display-message -p -t "$session_id" '#{session_name}' 2>/dev/null)"
if [ -z "$session_name" ]; then
    sketchybar --set "$NAME" drawing=off
    exit 0
fi

label_color="$MUTED_COLOR"
if tmux list-clients -F '#{session_id}' 2>/dev/null | grep -Fqx "$session_id"; then
    label_color="$GREEN_COLOR"
fi

sketchybar --set "$NAME" \
    drawing=on \
    label="$session_name" \
    label.color="$label_color"
