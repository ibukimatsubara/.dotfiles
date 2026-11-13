#!/usr/bin/env bash
# Toggle the on-screen keycast overlay (keys, clicks, wheel) for screen recordings.
set -euo pipefail
config="$HOME/.dotfiles/platforms/ubuntu/quickshell/keycast"
if qs list -p "$config" 2>/dev/null | grep -q '^Instance'; then
    qs kill -p "$config"
else
    qs -p "$config" -n -d
fi
