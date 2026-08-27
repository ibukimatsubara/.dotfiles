#!/usr/bin/env bash

set -euo pipefail

if [[ "$OSTYPE" != darwin* ]]; then
    echo "The tmux pane summary LaunchAgent currently supports macOS only." >&2
    exit 1
fi

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
label="com.local.tmux-pane-summaries"
launch_agent="$HOME/Library/LaunchAgents/$label.plist"

mkdir -p \
    "$HOME/Library/LaunchAgents" \
    "$HOME/Library/Logs" \
    "$HOME/Library/Caches/$label"

ln -sfn "$repo_dir/launchd/$label.plist" "$launch_agent"

if tmux list-sessions >/dev/null 2>&1; then
    tmux source-file "$repo_dir/tmux/tmux.conf"
fi

launchctl bootout "gui/$UID/$label" >/dev/null 2>&1 || true
launchctl enable "gui/$UID/$label"
launchctl bootstrap "gui/$UID" "$launch_agent"

echo "Installed and started $label"
echo "Interval: 15 minutes"
echo "Log: $HOME/Library/Logs/tmux-pane-summaries.log"
