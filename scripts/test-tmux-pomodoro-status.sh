#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
status_script="$repo_dir/scripts/tmux-status-sessions.sh"
temp_dir="$(mktemp -d)"
status_file="$temp_dir/tmux_status.tsv"
trap 'rm -rf "$temp_dir"' EXIT

current_session="$(tmux display-message -p '#{session_name}' 2>/dev/null \
    || tmux list-sessions -F '#{session_name}' 2>/dev/null | head -n 1)"
[ -n "$current_session" ] || {
    printf 'FAIL: no tmux session is available for status rendering\n' >&2
    exit 1
}

render_status() {
    TMUX_BREAK_TIMER_STATUS_FILE="$status_file" \
        TMUX_STATUS_NOW_EPOCH=2000 \
        "$status_script" "$current_session" 160 /tmp/test-project
}

assert_rendered() {
    local expected="$1"
    local rendered
    rendered="$(render_status)"
    if ! printf '%s\n' "$rendered" | rg -Fq "$expected"; then
        printf 'FAIL: expected Pomodoro status %q\n' "$expected" >&2
        exit 1
    fi
}

printf 'true\twork\t1000\t1800\n' > "$status_file"
assert_rendered '◷ 13:20'

printf 'true\tbreak\t1900\t180\n' > "$status_file"
assert_rendered '◷ 01:20'
assert_rendered 'fg=#c084fc'

printf 'true\twaiting\t2000\t0\n' > "$status_file"
assert_rendered '◷ ready'

printf 'false\twork\t2000\t1800\n' > "$status_file"
assert_rendered '◷ off'

printf 'PASS: tmux Pomodoro status renders work, break, ready, and off states\n'
