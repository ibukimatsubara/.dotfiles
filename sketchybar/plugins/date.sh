#!/bin/sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
PLUGIN_DIR="${PLUGIN_DIR:-$CONFIG_DIR/plugins}"

sketchybar --set "$NAME" label="$(date '+%a %m/%d')"

case "$SENDER" in
    mouse.clicked)
        "$PLUGIN_DIR/calendar_popup.sh" toggle
        ;;
    mouse.exited.global)
        sketchybar --set "$NAME" popup.drawing=off
        ;;
esac
