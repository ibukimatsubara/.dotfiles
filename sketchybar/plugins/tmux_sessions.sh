#!/bin/bash

# マウスホバー時はバー全体を非表示
if [ "$SENDER" = "mouse.entered" ]; then
    source "$CONFIG_DIR/plugins/bar_hover.sh"
    exit 0
fi

# 色定義
PINK="0xffff79c6"
CYAN="0xff8be9fd"
GREY="0xff6272a4"
WHITE="0xfff8f8f2"

# tmuxが起動していない場合
if ! tmux list-sessions &>/dev/null; then
    sketchybar --set $NAME label="tmux: --" label.color=$GREY
    exit 0
fi

# 現在のセッション取得（アクティブなクライアントから）
CURRENT_SESSION=$(tmux list-clients -F '#{session_name}' 2>/dev/null | head -1)

# セッション内のclaude/opencodeプロセスをカウント
# 戻り値: "active/total" (例: "1/3")
count_ai_processes() {
    local session=$1
    local total=0
    local active=0
    
    # セッション内の全ペインのPIDを取得
    while IFS= read -r pane_pid; do
        [ -z "$pane_pid" ] && continue
        
        # ペインの子プロセスでclaude/opencodeを検索
        while IFS= read -r ai_pid; do
            [ -z "$ai_pid" ] && continue
            total=$((total + 1))
            
            # CPU使用率で判断（0%より大きければアクティブ）
            local cpu=$(ps -p "$ai_pid" -o %cpu= 2>/dev/null | tr -d ' ')
            if [ -n "$cpu" ] && [ "$(echo "$cpu > 0.5" | bc 2>/dev/null)" = "1" ]; then
                active=$((active + 1))
            fi
        done < <(pgrep -P "$pane_pid" -f "claude|opencode" 2>/dev/null)
    done < <(tmux list-panes -s -t "$session" -F '#{pane_pid}' 2>/dev/null)
    
    echo "$active/$total"
}

# セッション名を省略（5文字以上は...で省略）
truncate_name() {
    local name=$1
    local max_len=5
    if [ ${#name} -gt $max_len ]; then
        echo "${name:0:$max_len}…"
    else
        echo "$name"
    fi
}

OUTPUT=""
HAS_ACTIVE=false
FIRST=true

while IFS= read -r session; do
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        OUTPUT+=" / "
    fi
    
    # AI プロセスをカウント
    AI_COUNT=$(count_ai_processes "$session")
    ACTIVE_COUNT=$(echo "$AI_COUNT" | cut -d'/' -f1)
    TOTAL_COUNT=$(echo "$AI_COUNT" | cut -d'/' -f2)
    
    # セッション名を省略して追加
    DISPLAY_NAME=$(truncate_name "$session")
    OUTPUT+="$DISPLAY_NAME"
    
    # AI プロセスがあれば数を追加
    if [ "$TOTAL_COUNT" -gt 0 ]; then
        OUTPUT+=" $AI_COUNT"
        if [ "$ACTIVE_COUNT" -gt 0 ]; then
            HAS_ACTIVE=true
        fi
    fi
done < <(tmux list-sessions -F '#S' 2>/dev/null)

if [ -z "$OUTPUT" ]; then
    OUTPUT="tmux: --"
    sketchybar --set $NAME label="$OUTPUT" label.color=$GREY
else
    # 色を決定: API通信中があればピンク、なければグレー
    if [ "$HAS_ACTIVE" = true ]; then
        sketchybar --set $NAME label="$OUTPUT" label.color=$PINK
    else
        sketchybar --set $NAME label="$OUTPUT" label.color=$WHITE
    fi
fi
