#!/usr/bin/env bash
# ローカル環境で tmux motion の実時間が体感上の上限以内か検証するベンチマーク。

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(dirname "$script_dir")
test_socket="dotfiles-tmux-motion-perf-$$"
budget_ms="${TMUX_MOTION_BUDGET_MS:-90}"
iterations=3

cleanup() {
    tmux -L "$test_socket" kill-server >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

now_us() {
    perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1000000'
}

tmux -L "$test_socket" -f "$repo_dir/tmux/tmux.conf" new-session \
    -d -s motion-perf -x 172 -y 48 'sleep 30'

if [ -n "${TMUX_MOTION_TEST_DELAY:-}" ]; then
    tmux -L "$test_socket" set-option -g @motion-frame-delay "$TMUX_MOTION_TEST_DELAY"
fi
if [ -n "${TMUX_MOTION_TEST_FRAMES:-}" ]; then
    tmux -L "$test_socket" set-option -g @motion-frames "$TMUX_MOTION_TEST_FRAMES"
fi
if [ -n "${TMUX_MOTION_TEST_STATUS:-}" ]; then
    tmux -L "$test_socket" set-option -g status "$TMUX_MOTION_TEST_STATUS"
fi

open_total_us=0
close_total_us=0
iteration=1
while [ "$iteration" -le "$iterations" ]; do
    source_pane=$(tmux -L "$test_socket" display-message -p -t motion-perf: '#{pane_id}')

    started=$(now_us)
    tmux -L "$test_socket" run-shell \
        "$script_dir/tmux-motion.sh open-rightmost '$source_pane'"
    opened=$(now_us)

    new_pane=$(tmux -L "$test_socket" display-message -p -t motion-perf: '#{pane_id}')
    tmux -L "$test_socket" run-shell \
        "$script_dir/tmux-motion.sh close-pane '$new_pane'"
    closed=$(now_us)

    open_total_us=$((open_total_us + opened - started))
    close_total_us=$((close_total_us + closed - opened))
    iteration=$((iteration + 1))
done

open_avg_ms=$((open_total_us / iterations / 1000))
close_avg_ms=$((close_total_us / iterations / 1000))

if [ "$open_avg_ms" -gt "$budget_ms" ] || [ "$close_avg_ms" -gt "$budget_ms" ]; then
    printf 'FAIL motion performance: open=%sms close=%sms budget=%sms\n' \
        "$open_avg_ms" "$close_avg_ms" "$budget_ms" >&2
    exit 1
fi

printf 'PASS motion performance: open=%sms close=%sms budget=%sms\n' \
    "$open_avg_ms" "$close_avg_ms" "$budget_ms"
