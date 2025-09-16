#!/bin/bash

# Combined DateTime with modern design
sketchybar --add item datetime right \
           --set datetime \
                 script="$PLUGIN_DIR/datetime_custom.sh" \
                 update_freq=1 \
                 icon.drawing=off \
                 label.font="SF Pro Display:Semibold:13" \
                 label.color=0xffffffff \
                 label.padding_left=12 \
                 label.padding_right=12 \
                 background.color=0xff2d3748 \
                 background.corner_radius=6 \
                 background.height=28 \
                 background.drawing=on \
                 background.border_color=0xffff79c6 \
                 background.border_width=2 \
                 click_script="open -a Calendar"