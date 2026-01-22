#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# 色定義（他のアイテムと統一）
GREY="0xff6272a4"
WHITE="0xfff8f8f2"

# 右側に配置（AI使用量の左に表示）
# マウスホバーで一時非表示
sketchybar --add item tmux_sessions right \
           --set tmux_sessions \
                 update_freq=5 \
                 script="$CONFIG_DIR/plugins/tmux_sessions.sh" \
                 icon="TMUX" \
                 icon.font="Hack Nerd Font Mono:Bold:11" \
                 icon.color=$GREY \
                 icon.padding_right=6 \
                 label.font="Hack Nerd Font Mono:Regular:11" \
                 label.color=$WHITE \
                 background.drawing=on \
                 padding_left=0 \
           --subscribe tmux_sessions mouse.entered
