#!/bin/bash

# Notifications item
sketchybar --add item notifications center \
           --set notifications \
                 script="$PLUGIN_DIR/notifications.sh" \
                 update_freq=30 \
                 icon.font="sketchybar-app-font:Regular:14" \
                 icon.color=0xff8b92a9 \
                 icon.padding_left=8 \
                 icon.padding_right=8 \
                 label.drawing=off \
                 background.color=$BAR_COLOR \
                 background.corner_radius=0 \
                 background.drawing=on
