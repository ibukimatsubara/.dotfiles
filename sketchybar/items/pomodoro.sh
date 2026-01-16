#!/bin/bash

# Pomodoro timer item (always visible)
sketchybar --add item pomodoro center \
           --set pomodoro \
                 script="$PLUGIN_DIR/pomodoro.sh" \
                 update_freq=1 \
                 icon.font="sketchybar-app-font:Regular:14" \
                 icon.color=0xffff79c6 \
                 icon.padding_left=6 \
                 icon.padding_right=6 \
                 icon.width=65 \
                 icon.align=center \
                 label.drawing=off \
                 background.color=$BAR_COLOR \
                 background.border_color=0xffff79c6 \
                 background.border_width=1 \
                 background.corner_radius=0 \
                 background.drawing=on \
                 drawing=on \
           --subscribe pomodoro mouse.clicked \
           --subscribe pomodoro mouse.clicked.right
