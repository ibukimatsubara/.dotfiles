#!/bin/bash

source "$CONFIG_DIR/colors.sh"

BLUE="0xff79c0ff"
GREY=$(getcolor white 75)

# CPU使用率 (スパークライン付き)
sketchybar --add item cpu left \
           --set cpu \
                 update_freq=3 \
                 script="$CONFIG_DIR/plugins/cpu.sh" \
                 label.font="Hack Nerd Font Mono:Regular:11" \
                 label.color=$BLUE \
                 icon="CPU" \
                 icon.font="Hack Nerd Font Mono:Bold:10" \
                 icon.color=$GREY \
                 icon.padding_right=6 \
                 background.drawing=off \
                 padding_right=15

# メモリ使用率 (スパークライン付き)
sketchybar --add item memory left \
           --set memory \
                 update_freq=3 \
                 script="$CONFIG_DIR/plugins/memory.sh" \
                 label.font="Hack Nerd Font Mono:Regular:11" \
                 label.color=$BLUE \
                 icon="MEM" \
                 icon.font="Hack Nerd Font Mono:Bold:10" \
                 icon.color=$GREY \
                 icon.padding_right=6 \
                 background.drawing=off \
                 padding_right=15

# バッテリー
sketchybar --add item battery left \
           --set battery \
                 update_freq=30 \
                 script="$CONFIG_DIR/plugins/battery.sh" \
                 label.font="Hack Nerd Font Mono:Regular:11" \
                 label.color=$GREY \
                 icon="BAT" \
                 icon.font="Hack Nerd Font Mono:Bold:10" \
                 icon.color=$GREY \
                 icon.padding_right=6 \
                 background.drawing=off
