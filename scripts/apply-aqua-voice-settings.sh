#!/bin/bash

set -euo pipefail

dotfiles_root="${DOTFILES_ROOT:-$HOME/.dotfiles}"
managed_settings="$dotfiles_root/aqua-voice/settings.json"
live_settings="$HOME/Library/Application Support/Aqua Voice/settings.json"

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required to apply Aqua Voice settings" >&2
    exit 1
fi

if [ ! -f "$managed_settings" ]; then
    echo "Managed Aqua Voice settings not found: $managed_settings" >&2
    exit 1
fi

if [ ! -f "$live_settings" ]; then
    echo "Aqua Voice settings not found; launch Aqua Voice once first" >&2
    exit 2
fi

if pgrep -x "Aqua Voice" >/dev/null 2>&1; then
    echo "Quit Aqua Voice before applying managed settings" >&2
    exit 2
fi

settings_dir="$(dirname "$live_settings")"
temporary_settings="$(mktemp "$settings_dir/settings.json.XXXXXX")"
trap 'rm -f "$temporary_settings"' EXIT

jq -s '.[0] * .[1]' "$live_settings" "$managed_settings" > "$temporary_settings"
chmod "$(stat -f '%Lp' "$live_settings")" "$temporary_settings"
mv "$temporary_settings" "$live_settings"
trap - EXIT

echo "Applied managed Aqua Voice settings"
