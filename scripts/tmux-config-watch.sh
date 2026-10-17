#!/usr/bin/env bash

# Reload the active tmux server when the managed config content changes.
# This process inherits TMUX from run-shell, so it follows the server/socket
# that started it instead of assuming the default socket.

set -u

config_path="${TMUX_CONFIG_PATH:-$HOME/.tmux.conf}"
watch_interval="${TMUX_CONFIG_WATCH_INTERVAL:-1}"
pid_option='@config-watcher-pid'
platform_config_path="${TMUX_CONFIG_PLATFORM_PATH:-}"
if [ -z "$platform_config_path" ] && [ -z "${TMUX_CONFIG_PATH:-}" ]; then
    case "$(uname -s)" in
        Darwin) platform_config_path="$HOME/.dotfiles/platforms/macos/tmux.conf" ;;
        Linux) platform_config_path="$HOME/.dotfiles/platforms/ubuntu/tmux.conf" ;;
    esac
fi

file_fingerprint() {
    local path="$1"
    if [ ! -f "$path" ]; then
        printf 'missing\n'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$path" | awk '{ print $1 }'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$path" | awk '{ print $1 }'
    else
        stat -f '%m:%z:%i' "$path" 2>/dev/null \
            || stat -c '%Y:%s:%i' "$path" 2>/dev/null
    fi
}

config_fingerprint() {
    if [ ! -f "$config_path" ]; then
        printf 'missing\n'
        return
    fi
    file_fingerprint "$config_path"
    if [ -n "$platform_config_path" ]; then
        file_fingerprint "$platform_config_path"
    fi
}

existing_pid="$(tmux show-option -gqv "$pid_option" 2>/dev/null)"
case "$existing_pid" in
    ''|*[!0-9]*) ;;
    *)
        if kill -0 "$existing_pid" 2>/dev/null; then
            exit 0
        fi
        ;;
esac

tmux set-option -gq "$pid_option" "$$" || exit 1

cleanup() {
    active_pid="$(tmux show-option -gqv "$pid_option" 2>/dev/null)"
    if [ "$active_pid" = "$$" ]; then
        tmux set-option -gu "$pid_option" 2>/dev/null || true
    fi
}
trap cleanup EXIT HUP INT TERM

previous_fingerprint="$(config_fingerprint)"

while tmux has-session >/dev/null 2>&1; do
    sleep "$watch_interval"
    current_fingerprint="$(config_fingerprint)"

    [ "$current_fingerprint" = "$previous_fingerprint" ] && continue
    previous_fingerprint="$current_fingerprint"

    if [ "$current_fingerprint" = 'missing' ]; then
        tmux display-message -d 3000 "tmux config missing: $config_path"
        continue
    fi

    reload_output="$(tmux source-file "$config_path" 2>&1)"
    reload_status=$?
    if [ "$reload_status" -eq 0 ]; then
        tmux display-message -d 1200 'tmux config reloaded'
    else
        tmux display-message -d 5000 "tmux config reload failed: $reload_output"
    fi
done
