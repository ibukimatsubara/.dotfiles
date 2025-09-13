#!/bin/bash

# Custom Battery with visual indicator
sketchybar --add item battery right \
           --set battery \
                 script="$PLUGIN_DIR/battery_custom.sh" \
                 update_freq=10 \
                 icon.font="JetBrainsMono Nerd Font:Regular:14" \
                 icon.color=0xffffffff \
                 icon.padding_left=8 \
                 icon.padding_right=4 \
                 label.font="SF Pro Display:Medium:12" \
                 label.color=0xffffffff \
                 label.padding_right=8 \
                 background.color=0xff2d3748 \
                 background.corner_radius=6 \
                 background.height=28 \
                 background.drawing=on \
                 click_script="open -a 'Activity Monitor'"