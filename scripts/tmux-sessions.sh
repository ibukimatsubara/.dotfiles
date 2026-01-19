#!/bin/bash
# tmuxセッション一覧を表示（現在のセッションをハイライト）

CURRENT_SESSION=$(tmux display-message -p '#S')

SESSIONS=()
while IFS= read -r session; do
    if [ "$session" = "$CURRENT_SESSION" ]; then
        # 現在のセッション: ピンクでハイライト
        SESSIONS+=("#[fg=#ff79c6,bold]$session#[fg=default,nobold]")
    else
        # 他のセッション: グレー
        SESSIONS+=("#[fg=colour245]$session#[fg=default]")
    fi
done < <(tmux list-sessions -F '#S' 2>/dev/null)

# / で結合
IFS='/'
echo "${SESSIONS[*]}" | sed 's|/| #[fg=colour240]/#[fg=default] |g'
