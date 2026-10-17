#!/usr/bin/env bash
set -euo pipefail
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/platforms/common/lib.sh"
source "$DOTFILES_ROOT/platforms/common/setup.sh"

applications_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$applications_dir"
for entry in "$DOTFILES_ROOT/platforms/ubuntu/applications/"*.desktop; do
    link_managed_path "$entry" "$applications_dir/$(basename "$entry")"
done
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$applications_dir"
fi
