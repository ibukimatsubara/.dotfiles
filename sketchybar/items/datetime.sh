#!/bin/bash

source "$CONFIG_DIR/colors.sh"

GREY=$(getcolor white 75)

sketchybar --add item datetime right \
           --set datetime \
                 update_freq=30 \
                 script="$CONFIG_DIR/plugins/datetime.sh" \
                 label.font="Hack Nerd Font Mono:Regular:12" \
                 label.color=$GREY \
                 icon.drawing=off \
                 background.drawing=off
