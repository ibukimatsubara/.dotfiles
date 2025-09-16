#!/bin/bash

# Notifications item
sketchybar --add item notifications right \
           --set notifications \
                 script="$PLUGIN_DIR/notifications.sh" \
                 update_freq=30 \
                 icon.font="sketchybar-app-font:Regular:14" \
                 icon.color=0xff8b92a9 \
                 icon.padding_left=8 \
                 icon.padding_right=8 \
                 label.drawing=off \
                 background.color=0xff1a202c \
                 background.corner_radius=6 \
                 background.height=28 \
                 background.drawing=on