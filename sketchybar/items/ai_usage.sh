#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# 色定義 (tmuxと完全に同じ)
PINK="0xffff79c6"      # Claude
CYAN="0xff8be9fd"      # Copilot
ORANGE="0xffffb86c"    # Zed

# 各プロバイダーを個別アイテムとして追加 (tmuxと同じ: Claude, Copilot, Zed)
# 右側に配置 (右から左に追加されるので逆順)
# マウスホバーで一時非表示
sketchybar --add item ai_zed right \
           --set ai_zed \
                 update_freq=60 \
                 script="$CONFIG_DIR/plugins/ai_zed.sh" \
                 label.font="Hack Nerd Font Mono:Regular:11" \
                 label.color=$ORANGE \
                 icon="Zed" \
                 icon.font="Hack Nerd Font Mono:Bold:11" \
                 icon.color=$ORANGE \
                 icon.padding_right=6 \
                 background.drawing=on \
                 padding_left=0 \
           --subscribe ai_zed mouse.entered

sketchybar --add item ai_copilot right \
           --set ai_copilot \
                 update_freq=60 \
                 script="$CONFIG_DIR/plugins/ai_copilot.sh" \
                 label.font="Hack Nerd Font Mono:Regular:11" \
                 label.color=$CYAN \
                 icon="Copilot" \
                 icon.font="Hack Nerd Font Mono:Bold:11" \
                 icon.color=$CYAN \
                 icon.padding_right=6 \
                 background.drawing=on \
                 padding_left=0 \
           --subscribe ai_copilot mouse.entered

sketchybar --add item ai_claude right \
           --set ai_claude \
                 update_freq=60 \
                 script="$CONFIG_DIR/plugins/ai_claude.sh" \
                 label.font="Hack Nerd Font Mono:Regular:11" \
                 label.color=$PINK \
                 icon="Claude" \
                 icon.font="Hack Nerd Font Mono:Bold:11" \
                 icon.color=$PINK \
                 icon.padding_right=6 \
                 background.drawing=on \
                 padding_left=0 \
           --subscribe ai_claude mouse.entered
