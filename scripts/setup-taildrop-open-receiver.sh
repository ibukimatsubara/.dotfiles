#!/bin/bash

set -euo pipefail

if [[ "$OSTYPE" != darwin* ]]; then
    echo "The Taildrop open receiver currently supports macOS only." >&2
    exit 1
fi

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
label="com.local.taildrop-open"
launch_agent="$HOME/Library/LaunchAgents/$label.plist"

mkdir -p \
    "$HOME/.local/bin" \
    "$HOME/Library/LaunchAgents" \
    "$HOME/Library/Logs" \
    "$HOME/Library/Caches/com.local.taildrop-open/incoming" \
    "$HOME/Downloads/svm-preview" \
    "$HOME/Downloads/Taildrop"

ln -sfn "$repo_dir/scripts/taildrop-open-receiver.sh" "$HOME/.local/bin/taildrop-open-receiver"
ln -sfn "$repo_dir/launchd/$label.plist" "$launch_agent"

launchctl bootout "gui/$UID/$label" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$UID" "$launch_agent"
launchctl enable "gui/$UID/$label"
launchctl kickstart -k "gui/$UID/$label"

echo "Installed and started $label"
echo "Preview directory: $HOME/Downloads/svm-preview"
echo "Log: $HOME/Library/Logs/svm-open-receiver.log"
