#!/usr/bin/env bash
set -euo pipefail
region="$(slurp)" || exit 0
screenshot_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$screenshot_dir"
screenshot="$(mktemp "$screenshot_dir/$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX.png")"
if ! grim -g "$region" "$screenshot"; then
    rm -f "$screenshot"
    exit 1
fi
wl-copy --type image/png < "$screenshot"
notify-send 'Screenshot saved and copied' "$screenshot"
