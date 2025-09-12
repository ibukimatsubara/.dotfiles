#!/bin/bash

# Simple Focus Mode Toggle with Moon Icon
sketchybar --add item focus_toggle right \
           --set focus_toggle \
                 script="$PLUGIN_DIR/focus_toggle_simple.sh" \
                 update_freq=10 \
                 icon.font="JetBrainsMono Nerd Font:Regular:16" \
                 icon="󰖔" \
                 icon.color=0xff6272a4 \
                 icon.padding_left=8 \
                 icon.padding_right=8 \
                 label.drawing=off \
                 background.color=0x226272a4 \
                 background.corner_radius=6 \
                 background.height=24 \
                 background.drawing=on \
                 click_script="$PLUGIN_DIR/focus_toggle_action.sh" \
           --subscribe focus_toggle system_woke focus_changed