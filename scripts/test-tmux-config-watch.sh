#!/usr/bin/env bash

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
watcher="$script_dir/tmux-config-watch.sh"
test_socket="dotfiles-tmux-config-watch-$$"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/tmux-config-watch-test.XXXXXX")"
test_config="$test_root/tmux.conf"
test_overlay="$test_root/platform.conf"

cleanup() {
    tmux -L "$test_socket" kill-server >/dev/null 2>&1 || true
    rm -rf "$test_root"
}
trap cleanup EXIT HUP INT TERM

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

wait_for_option() {
    expected="$1"
    attempts=0
    while [ "$attempts" -lt 40 ]; do
        actual="$(tmux -L "$test_socket" show-option -gqv @watch-test 2>/dev/null)"
        [ "$actual" = "$expected" ] && return 0
        sleep 0.05
        attempts=$((attempts + 1))
    done
    return 1
}

printf "set -g @watch-test 'before'\n" > "$test_config"
printf "set -g @watch-test 'overlay-before'\n" > "$test_overlay"
tmux -L "$test_socket" -f /dev/null new-session -d -s config-watch 'sleep 30'
tmux -L "$test_socket" set-option -g @watch-test before
tmux -L "$test_socket" run-shell -b \
    "TMUX_CONFIG_PATH='$test_config' TMUX_CONFIG_PLATFORM_PATH='$test_overlay' TMUX_CONFIG_WATCH_INTERVAL=0.05 '$watcher'"

attempts=0
while [ -z "$(tmux -L "$test_socket" show-option -gqv @config-watcher-pid)" ] && \
      [ "$attempts" -lt 40 ]; do
    sleep 0.05
    attempts=$((attempts + 1))
done
watcher_pid="$(tmux -L "$test_socket" show-option -gqv @config-watcher-pid)"
[ -n "$watcher_pid" ] || fail 'watcher did not start'

tmux -L "$test_socket" run-shell -b \
    "TMUX_CONFIG_PATH='$test_config' TMUX_CONFIG_PLATFORM_PATH='$test_overlay' TMUX_CONFIG_WATCH_INTERVAL=0.05 '$watcher'"
sleep 0.1
[ "$(tmux -L "$test_socket" show-option -gqv @config-watcher-pid)" = "$watcher_pid" ] \
    || fail 'a duplicate watcher replaced the active watcher'

printf "set -g @watch-test 'after'\n" > "$test_config"
wait_for_option after || fail 'config change was not reloaded'

printf 'source-file "%s"\n' "$test_overlay" >> "$test_config"
wait_for_option overlay-before || fail 'overlay was not loaded'
printf "set -g @watch-test 'overlay-after'\n" > "$test_overlay"
wait_for_option overlay-after || fail 'OS overlay change was not reloaded'

printf 'PASS: tmux main/OS config changes reload with one watcher per server\n'
