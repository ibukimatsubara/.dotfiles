#!/bin/bash

# Current application display
sketchybar --add item front_app left \
           --set front_app \
                 script="$PLUGIN_DIR/front_app.sh" \
                 icon.font="sketchybar-app-font:Regular:16" \
                 icon.color=0xff50fa7b \
                 icon.padding_left=8 \
                 icon.padding_right=4 \
                 label.font="SF Pro Display:Medium:12" \
                 label.color=0xffffffff \
                 label.padding_right=8 \
                 background.color=0xff1a202c \
                 background.corner_radius=6 \
                 background.height=28 \
                 background.drawing=on \
                 updates=on