#!/usr/bin/env bash
# Toggle the keycast overlay owned by the desktop shell (a standalone qs would escape the watcher).
set -euo pipefail
scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config="$(cd "$scripts_dir/../platforms/ubuntu/quickshell/keycast" && pwd)"
exec "$scripts_dir/hyprland-native.sh" qs ipc -p "$config" call keycast toggle
