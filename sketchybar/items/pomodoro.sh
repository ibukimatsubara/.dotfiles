#!/bin/bash

# Pomodoro timer item (initially hidden)
sketchybar --add item pomodoro right \
           --set pomodoro \
                 script="$PLUGIN_DIR/pomodoro.sh" \
                 update_freq=1 \
                 icon.font="sketchybar-app-font:Regular:14" \
                 icon.color=0xffffffff \
                 icon.padding_left=6 \
                 icon.padding_right=6 \
                 icon.width=65 \
                 icon.align=center \
                 label.drawing=off \
                 background.color=0xff4a90e2 \
                 background.corner_radius=6 \
                 background.height=28 \
                 background.drawing=on \
                 drawing=off \
           --subscribe pomodoro mouse.clicked \
           --subscribe pomodoro mouse.clicked.right