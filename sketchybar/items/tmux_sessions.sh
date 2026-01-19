#!/bin/bash

source "$CONFIG_DIR/colors.sh"

PINK=$(getcolor maroon)
GREY=$(getcolor white 50)

sketchybar --add item tmux_sessions left \
           --set tmux_sessions \
                 update_freq=5 \
                 script="$CONFIG_DIR/plugins/tmux_sessions.sh" \
                 label.font="Hack Nerd Font Mono:Regular:12" \
                 label.color=$GREY \
                 icon.drawing=off \
                 background.drawing=off
