#!/bin/bash

# Pomodoro timer item (右側、日時の左に配置)
# 他のアイテムと同じスタイル（枠線なし、アイコン+ラベル形式）
GREY="0xff6272a4"
PINK="0xffff79c6"

sketchybar --add item pomodoro right \
           --set pomodoro \
                 script="$PLUGIN_DIR/pomodoro.sh" \
                 update_freq=1 \
                 icon="POM" \
                 icon.font="Hack Nerd Font Mono:Bold:11" \
                 icon.color=$GREY \
                 icon.padding_right=6 \
                 label.font="Hack Nerd Font Mono:Regular:11" \
                 label.color=$PINK \
                 background.drawing=on \
                 padding_left=0 \
                 drawing=on \
           --subscribe pomodoro mouse.clicked \
           --subscribe pomodoro mouse.clicked.right
