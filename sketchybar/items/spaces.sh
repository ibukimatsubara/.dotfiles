#!/bin/bash

# Get ALL existing spaces from yabai (across all displays)
SPACES=$(yabai -m query --spaces | jq -r '.[].index' | sort -n)

# Add only existing spaces (force all to main display)
for sid in $SPACES; do
  sketchybar --add space space.$sid left \
    --set space.$sid associated_space=$sid \
                     associated_display=1 \
                     icon="$sid" \
                     icon.color=0xff8b92a9 \
                     icon.highlight_color=0xff50fa7b \
                     icon.font="SF Pro Display:Bold:14" \
                     icon.padding_left=8 \
                     icon.padding_right=4 \
                     label.drawing=on \
                     label.font="sketchybar-app-font:Regular:10" \
                     label.padding_left=2 \
                     label.padding_right=8 \
                     background.color=0xff1a202c \
                     background.corner_radius=6 \
                     background.height=28 \
                     background.drawing=off \
                     background.highlight_color=0xff2d3748 \
                     script="$PLUGIN_DIR/space_windows.sh" \
                     click_script="yabai -m space --focus $sid"
done

# Create bracket for all spaces (without separator) with pink outline
sketchybar --add bracket spaces_bracket '/space\..*/' \
           --set spaces_bracket background.color=0xff1a202c \
                               background.corner_radius=10 \
                               background.height=34 \
                               background.padding_left=0 \
                               background.padding_right=8 \
                               background.drawing=on \
                               background.border_color=0xffff79c6 \
                               background.border_width=2