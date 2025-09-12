#!/bin/bash

# Custom DateTime with modern design
sketchybar --add item clock right \
           --set clock \
                 script="$PLUGIN_DIR/datetime_custom.sh" \
                 update_freq=1 \
                 icon.drawing=off \
                 label.font="SF Pro Display:Semibold:13" \
                 label.color=0xffffffff \
                 label.padding_left=8 \
                 label.padding_right=8 \
                 background.color=0x33ffffff \
                 background.corner_radius=6 \
                 background.height=24 \
                 background.drawing=on \
                 click_script="open -a Calendar" \
                 \
           --add item date right \
           --set date \
                 script="$PLUGIN_DIR/datetime_custom.sh" \
                 update_freq=60 \
                 icon.drawing=off \
                 label.font="SF Pro Display:Regular:11" \
                 label.color=0xaaffffff \
                 label.padding_left=8 \
                 label.padding_right=0 \
                 background.drawing=off