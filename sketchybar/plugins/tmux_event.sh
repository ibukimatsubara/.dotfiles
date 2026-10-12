#!/bin/sh

if command -v sketchybar >/dev/null 2>&1; then
    sketchybar_bin="$(command -v sketchybar)"
elif [ -x /opt/homebrew/bin/sketchybar ]; then
    sketchybar_bin=/opt/homebrew/bin/sketchybar
elif [ -x /usr/local/bin/sketchybar ]; then
    sketchybar_bin=/usr/local/bin/sketchybar
else
    exit 0
fi

if [ "$1" = "reload" ]; then
    "$sketchybar_bin" --reload
else
    "$sketchybar_bin" --trigger tmux_state_changed
fi
