#!/bin/bash

# 色定義
PINK="0xffff79c6"
GREY="0xff6272a4"

# tmuxが起動していない場合
if ! tmux list-sessions &>/dev/null; then
    sketchybar --set $NAME label="tmux: --"
    exit 0
fi

# 現在のセッション取得（アクティブなクライアントから）
CURRENT_SESSION=$(tmux list-clients -F '#{session_name}' 2>/dev/null | head -1)

OUTPUT=""
FIRST=true
while IFS= read -r session; do
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        OUTPUT+=" / "
    fi
    
    if [ "$session" = "$CURRENT_SESSION" ]; then
        OUTPUT+="$session"
    else
        OUTPUT+="$session"
    fi
done < <(tmux list-sessions -F '#S' 2>/dev/null)

if [ -z "$OUTPUT" ]; then
    OUTPUT="tmux: --"
fi

# 現在のセッションをハイライト表示
sketchybar --set $NAME label="$OUTPUT" label.color=$PINK
