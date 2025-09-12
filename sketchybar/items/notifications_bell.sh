#!/bin/bash

# Simple Notification Bell - Display only (no click interaction)
sketchybar --add item notifications_bell right \
           --set notifications_bell \
                 script="$PLUGIN_DIR/notifications_bell.sh" \
                 update_freq=30 \
                 icon.font="JetBrainsMono Nerd Font:Regular:14" \
                 icon="󰂚" \
                 icon.color=0xffffffff \
                 icon.padding_left=8 \
                 icon.padding_right=8 \
                 label.drawing=on \
                 label.font="SF Pro Display:Medium:11" \
                 label.color=0xffffffff \
                 label.padding_left=4 \
                 label.padding_right=8 \
                 background.color=0xff2d3748 \
                 background.corner_radius=6 \
                 background.height=28 \
                 background.drawing=on