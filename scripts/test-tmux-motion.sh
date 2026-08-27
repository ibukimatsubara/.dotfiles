#!/usr/bin/env bash
# tmux motion 後もルート横並びペインが等幅であることを検証する。

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
test_socket="dotfiles-tmux-motion-test-$$"

cleanup() {
    tmux -L "$test_socket" kill-server >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

assert_equal_widths() {
    local label widths spread

    label="$1"
    widths=$(tmux -L "$test_socket" list-panes -t motion-test: -F '#{pane_width}')
    spread=$(
        printf '%s\n' "$widths" \
            | awk '
                NR == 1 { min = $1; max = $1 }
                $1 < min { min = $1 }
                $1 > max { max = $1 }
                END { print max - min }
            '
    )

    if [ "$spread" -gt 1 ]; then
        printf 'FAIL %s: pane widths differ by %s (widths: %s)\n' \
            "$label" "$spread" "$(printf '%s' "$widths" | tr '\n' ' ')" >&2
        return 1
    fi

    printf 'PASS %s: widths=%s\n' "$label" "$(printf '%s' "$widths" | tr '\n' ' ')"
}

tmux -L "$test_socket" -f /dev/null new-session \
    -d -s motion-test -x 120 -y 40 -c /tmp 'sleep 30'
tmux -L "$test_socket" set-option -g @motion-enabled on
tmux -L "$test_socket" set-option -g @motion-frames 3
tmux -L "$test_socket" set-option -g @motion-frame-delay 0.001
tmux -L "$test_socket" set-hook -g after-kill-pane \
    "run-shell '$script_dir/tmux-balance-horizontal.sh #{hook_window}'"

first_pane=$(tmux -L "$test_socket" display-message -p -t motion-test: '#{pane_id}')
tmux -L "$test_socket" split-window -h -t motion-test: -c / 'sleep 30'
tmux -L "$test_socket" select-pane -t "$first_pane"
tmux -L "$test_socket" run-shell \
    "$script_dir/tmux-motion.sh open-rightmost '$first_pane'"

assert_equal_widths 'open-rightmost'

third_pane=$(tmux -L "$test_socket" display-message -p -t motion-test: '#{pane_id}')
tmux -L "$test_socket" run-shell \
    "$script_dir/tmux-motion.sh open-rightmost '$third_pane'"

assert_equal_widths 'open-rightmost-four-panes'

new_pane=$(tmux -L "$test_socket" display-message -p -t motion-test: '#{pane_id}')
tmux -L "$test_socket" run-shell \
    "$script_dir/tmux-motion.sh close-pane '$new_pane'"

assert_equal_widths 'close-pane-to-three'

new_pane=$(tmux -L "$test_socket" display-message -p -t motion-test: '#{pane_id}')
tmux -L "$test_socket" run-shell \
    "$script_dir/tmux-motion.sh close-pane '$new_pane'"

assert_equal_widths 'close-pane-to-two'

tmux -L "$test_socket" set-option -g @motion-codex-command 'exec sleep 30'
source_pane=$(tmux -L "$test_socket" display-message -p -t motion-test: '#{pane_id}')
tmux -L "$test_socket" run-shell \
    "$script_dir/tmux-motion.sh open-rightmost-codex '$source_pane'"

assert_equal_widths 'open-rightmost-command'
active_command=$(tmux -L "$test_socket" display-message -p -t motion-test: '#{pane_current_command}')
if [ "$active_command" != 'sleep' ]; then
    printf 'FAIL open-rightmost-command: expected sleep, got %s\n' "$active_command" >&2
    exit 1
fi
printf 'PASS open-rightmost-command: command=%s\n' "$active_command"

command_pane=$(tmux -L "$test_socket" display-message -p -t motion-test: '#{pane_id}')
tmux -L "$test_socket" run-shell \
    "$script_dir/tmux-motion.sh soft-close-pane '$command_pane'"
assert_equal_widths 'soft-close-pane'

restore_from=$(tmux -L "$test_socket" display-message -p -t motion-test: '#{pane_id}')
tmux -L "$test_socket" run-shell \
    "$script_dir/tmux-motion.sh undo-last-pane '$restore_from'"
assert_equal_widths 'undo-last-pane'

restored_command=$(tmux -L "$test_socket" display-message -p -t "$command_pane" '#{pane_current_command}')
if [ "$restored_command" != 'sleep' ]; then
    printf 'FAIL undo-last-pane: expected running sleep, got %s\n' "$restored_command" >&2
    exit 1
fi
printf 'PASS undo-last-pane: command=%s\n' "$restored_command"
