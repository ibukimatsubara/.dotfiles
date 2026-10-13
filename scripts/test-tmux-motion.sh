#!/usr/bin/env bash
# tmux motion 後もルート横並びペインが等幅であることを検証する。

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
test_socket="dotfiles-tmux-motion-test-$$"
custom_path=$(mktemp -d "${TMPDIR:-/tmp}/tmux-motion-path.XXXXXX")
custom_path=$(cd "$custom_path" && pwd -P)

cleanup() {
    tmux -L "$test_socket" kill-server >/dev/null 2>&1 || true
    rm -rf "$custom_path"
}
trap cleanup EXIT HUP INT TERM

assert_equal_widths() {
    local label target widths spread

    label="$1"
    target="${2:-motion-test:}"
    widths=$(tmux -L "$test_socket" list-panes -t "$target" -F '#{pane_width}')
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
tmux -L "$test_socket" set-option -g remain-on-exit on
tmux -L "$test_socket" set-hook -g pane-died \
    "run-shell -b \"$script_dir/tmux-motion.sh close-pane #{hook_pane}\""

# pane-died が inactive window の終了元を正しく整列することを検証する。
tmux -L "$test_socket" new-window -d -t motion-test: -n hook-target -c /tmp 'sleep 30'
tmux -L "$test_socket" split-window -h -t motion-test:hook-target -l 20 'sleep 30'
exiting_pane=$(tmux -L "$test_socket" split-window -d -h -t motion-test:hook-target \
    -l 10 -P -F '#{pane_id}' 'sleep 0.1')
for _ in $(seq 1 50); do
    if ! tmux -L "$test_socket" list-panes -a -F '#{pane_id}' | rg -Fxq "$exiting_pane"; then
        break
    fi
    sleep 0.05
done
if tmux -L "$test_socket" list-panes -a -F '#{pane_id}' | rg -Fxq "$exiting_pane"; then
    printf 'FAIL pane-died-inactive-window: pane %s was not removed\n' "$exiting_pane" >&2
    exit 1
fi
# pane-died hook runs in the background. Pane removal becomes visible just
# before its final rebalance command completes, so wait for that second phase.
for _ in $(seq 1 50); do
    hook_widths=$(tmux -L "$test_socket" list-panes -t motion-test:hook-target -F '#{pane_width}')
    hook_spread=$(
        printf '%s\n' "$hook_widths" \
            | awk '
                NR == 1 { min = $1; max = $1 }
                $1 < min { min = $1 }
                $1 > max { max = $1 }
                END { print max - min }
            '
    )
    [ "$hook_spread" -le 1 ] && break
    sleep 0.05
done
assert_equal_widths 'pane-died-inactive-window' 'motion-test:hook-target'

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

path_source=$(tmux -L "$test_socket" display-message -p -t motion-test: '#{pane_id}')
tmux -L "$test_socket" run-shell \
    "$script_dir/tmux-motion.sh open-rightmost '$path_source' '$custom_path'"
opened_path=$(tmux -L "$test_socket" display-message -p -t motion-test: '#{pane_current_path}')
if [ "$opened_path" != "$custom_path" ]; then
    printf 'FAIL open-rightmost-path: expected %s, got %s\n' "$custom_path" "$opened_path" >&2
    exit 1
fi
printf 'PASS open-rightmost-path: path=%s\n' "$opened_path"
path_pane=$(tmux -L "$test_socket" display-message -p -t motion-test: '#{pane_id}')
tmux -L "$test_socket" run-shell \
    "$script_dir/tmux-motion.sh close-pane '$path_pane'"
assert_equal_widths 'close-custom-path-pane'

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
