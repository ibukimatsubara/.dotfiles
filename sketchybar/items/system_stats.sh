#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# tmuxと同じ色
BLUE="0xff79c0ff"      # 数値の色
GREY="0xff6272a4"      # ラベル(CPU/MEM/BAT)の色 (colour245相当)

# tmuxと同じ配置: 右側に CPU MEM BAT 日時
# SketchyBarの右側は右から左に配置されるので、逆順で追加
# 日時はdatetime.shで別途追加されるので、ここではCPU/MEM/BATのみ

# CPU使用率 (スパークライン付き)
sketchybar --add item cpu right \
           --set cpu \
                 update_freq=5 \
                 script="$CONFIG_DIR/plugins/cpu.sh" \
                 label.font="Hack Nerd Font Mono:Regular:11" \
                 label.color=$BLUE \
                 icon="CPU" \
                 icon.font="Hack Nerd Font Mono:Bold:11" \
                 icon.color=$GREY \
                 icon.padding_right=6 \
                 background.drawing=off \
                 padding_left=15

# メモリ使用率 (スパークライン付き)
sketchybar --add item memory right \
           --set memory \
                 update_freq=5 \
                 script="$CONFIG_DIR/plugins/memory.sh" \
                 label.font="Hack Nerd Font Mono:Regular:11" \
                 label.color=$BLUE \
                 icon="MEM" \
                 icon.font="Hack Nerd Font Mono:Bold:11" \
                 icon.color=$GREY \
                 icon.padding_right=6 \
                 background.drawing=off \
                 padding_left=15

# バッテリー
sketchybar --add item battery right \
           --set battery \
                 update_freq=30 \
                 script="$CONFIG_DIR/plugins/battery.sh" \
                 label.font="Hack Nerd Font Mono:Regular:11" \
                 label.color=$BLUE \
                 icon="BAT" \
                 icon.font="Hack Nerd Font Mono:Bold:11" \
                 icon.color=$GREY \
                 icon.padding_right=6 \
                 background.drawing=off \
                 padding_left=15
