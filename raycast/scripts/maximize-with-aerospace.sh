#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Maximize with AeroSpace
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🖥️
# @raycast.packageName AeroSpace Window Management
# @raycast.description Toggle the focused window while preserving AeroSpace outer gaps.

set -euo pipefail

if command -v aerospace >/dev/null 2>&1; then
  aerospace_bin="$(command -v aerospace)"
elif [[ -x /opt/homebrew/bin/aerospace ]]; then
  aerospace_bin=/opt/homebrew/bin/aerospace
elif [[ -x /usr/local/bin/aerospace ]]; then
  aerospace_bin=/usr/local/bin/aerospace
else
  echo "AeroSpace CLI was not found" >&2
  exit 1
fi

window_id="$($aerospace_bin list-windows --focused --format '%{window-id}')"

if [[ -z "$window_id" ]]; then
  echo "No focused AeroSpace window was found" >&2
  exit 1
fi

"$aerospace_bin" fullscreen --window-id "$window_id"
