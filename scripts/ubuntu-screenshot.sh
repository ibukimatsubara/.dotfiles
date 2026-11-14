#!/usr/bin/env bash
set -euo pipefail
# "full" captures every monitor; otherwise select a region first.
if [[ "${1:-}" == full ]]; then
    grim_args=()
else
    region="$(slurp)" || exit 0
    grim_args=(-g "$region")
fi
screenshot_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$screenshot_dir"
screenshot="$(mktemp "$screenshot_dir/$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX.png")"
if ! grim "${grim_args[@]}" "$screenshot"; then
    rm -f "$screenshot"
    exit 1
fi
wl-copy --type image/png < "$screenshot"
notify-send 'Screenshot saved and copied' "$screenshot"
