#!/bin/bash

# Custom Notification Center with modern design
sketchybar --add item notifications right \
           --set notifications \
                 script="$PLUGIN_DIR/notifications_custom.sh" \
                 update_freq=5 \
                 icon.font="JetBrainsMono Nerd Font:Regular:14" \
                 icon="󰂚" \
                 icon.color=0xffffffff \
                 icon.padding_left=8 \
                 icon.padding_right=4 \
                 label.font="SF Pro Display:Medium:11" \
                 label.color=0xffffffff \
                 label.padding_right=8 \
                 background.color=0x33bd93f9 \
                 background.corner_radius=6 \
                 background.height=24 \
                 background.drawing=on \
                 click_script="$PLUGIN_DIR/focus_toggle.sh" \
           --subscribe notifications system_woke focus_changed