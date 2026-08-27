#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
status_script="$repo_dir/scripts/tmux-status-sessions.sh"
tmux_config="$repo_dir/tmux/tmux.conf"

current_session="$(tmux display-message -p '#{session_name}' 2>/dev/null \
    || tmux list-sessions -F '#{session_name}' 2>/dev/null | head -n 1)"
[ -n "$current_session" ] || {
    printf 'FAIL: no tmux session is available for status rendering\n' >&2
    exit 1
}
rendered="$($status_script "$current_session" 160 /tmp/test-project)"

if printf '%s\n' "$rendered" | rg -q 'bg=#0d1117'; then
    printf 'FAIL: status generator paints the canvas opaque\n' >&2
    exit 1
fi

if ! rg -q '^set -g status-style ".*bg=default' "$tmux_config"; then
    printf 'FAIL: tmux status-style does not inherit terminal transparency\n' >&2
    exit 1
fi

if ! printf '%s\n' "$rendered" | rg -q 'bg=#5eead4'; then
    printf 'FAIL: active session pill lost its accent background\n' >&2
    exit 1
fi

printf 'PASS: status canvas is transparent and session pills remain styled\n'
