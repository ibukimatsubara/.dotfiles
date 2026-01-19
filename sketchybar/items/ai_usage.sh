#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# 色定義 (tmuxと同じ)
PINK="0xffff79c6"
BLUE="0xff79c0ff"
PURPLE="0xffbd93f9"
CYAN="0xff8be9fd"
ORANGE="0xffffb86c"
GREY="0xff6272a4"

# 各プロバイダーを個別アイテムとして追加
sketchybar --add item ai_claude center \
           --set ai_claude \
                 update_freq=60 \
                 script="$CONFIG_DIR/plugins/ai_claude.sh" \
                 label.font="Hack Nerd Font Mono:Regular:12" \
                 label.color=$PINK \
                 icon.drawing=off \
                 background.drawing=off \
                 padding_right=20

sketchybar --add item ai_codex center \
           --set ai_codex \
                 update_freq=60 \
                 script="$CONFIG_DIR/plugins/ai_codex.sh" \
                 label.font="Hack Nerd Font Mono:Regular:12" \
                 label.color=$BLUE \
                 icon.drawing=off \
                 background.drawing=off \
                 padding_right=20

sketchybar --add item ai_gemini center \
           --set ai_gemini \
                 update_freq=60 \
                 script="$CONFIG_DIR/plugins/ai_gemini.sh" \
                 label.font="Hack Nerd Font Mono:Regular:12" \
                 label.color=$PURPLE \
                 icon.drawing=off \
                 background.drawing=off \
                 padding_right=20

sketchybar --add item ai_copilot center \
           --set ai_copilot \
                 update_freq=60 \
                 script="$CONFIG_DIR/plugins/ai_copilot.sh" \
                 label.font="Hack Nerd Font Mono:Regular:12" \
                 label.color=$CYAN \
                 icon.drawing=off \
                 background.drawing=off
