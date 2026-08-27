#!/bin/bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <local-taildrop-device>" >&2
    exit 2
fi

taildrop_target="$1"
case "$taildrop_target" in
    ""|*[!A-Za-z0-9._-]*)
        echo "Invalid Taildrop device name: $taildrop_target" >&2
        exit 2
        ;;
esac

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$HOME/.local/bin" "$HOME/.config/open-local"
ln -sfn "$repo_dir/scripts/open-local.sh" "$HOME/.local/bin/open-local"

umask 077
printf 'TAILDROP_TARGET=%s\n' "$taildrop_target" > "$HOME/.config/open-local/config"

if [ ! -e "$HOME/AGENTS.md" ] && [ ! -L "$HOME/AGENTS.md" ]; then
    ln -s "$repo_dir/codex/remote-home-AGENTS.md" "$HOME/AGENTS.md"
    echo "Linked Codex instructions: $HOME/AGENTS.md"
else
    echo "Kept existing $HOME/AGENTS.md; merge codex/remote-home-AGENTS.md manually if needed"
fi

echo "Installed sender: $HOME/.local/bin/open-local"
echo "Taildrop target: $taildrop_target"
