#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# tmuxと同じ色 (#f8f8f2 = Dracula white)
WHITE="0xfff8f8f2"

sketchybar --add item datetime right \
           --set datetime \
                 update_freq=30 \
                 script="$CONFIG_DIR/plugins/datetime.sh" \
                 label.font="Hack Nerd Font Mono:Regular:11" \
                 label.color=$WHITE \
                 icon.drawing=off \
                 background.drawing=off
