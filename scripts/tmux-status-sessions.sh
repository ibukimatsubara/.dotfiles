#!/usr/bin/env bash
# セッション一覧をステータスバー中央に表示（今いるセッションだけハイライト、順番は固定）
# $1: 現在のセッション名, $2: クライアント幅（#S / #{client_width} 展開経由で渡す）

current="$1"
width="${2:-0}"

output=""
while IFS= read -r session; do
    [ -n "$output" ] && output+=" #[fg=colour240]/#[default] "
    if [ "$session" = "$current" ]; then
        output+="#[fg=#ff79c6,bold]${session}#[default]"
    else
        output+="#[fg=colour245]${session}#[default]"
    fi
done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null)

# tmuxのスタイルコードを除いた実表示文字数から中央寄せの余白を計算
plain=$(echo "$output" | sed -E 's/#\[[^]]*\]//g')
len=${#plain}

pad=0
if [ "$width" -gt "$len" ] 2>/dev/null; then
    pad=$(( (width - len) / 2 ))
fi

printf '%*s%s\n' "$pad" '' "$output"
