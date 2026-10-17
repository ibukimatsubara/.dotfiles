#!/usr/bin/env bash
# Apply the repository's versioned QML customizations to an installed shell.
set -euo pipefail
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_ROOT/platforms/common/lib.sh"
source "$DOTFILES_ROOT/platforms/common/setup.sh"
shell_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
overrides="$DOTFILES_ROOT/platforms/ubuntu/caelestia"
if [ ! -f "$shell_dir/shell.qml" ]; then
    print_error 'Install Caelestia Shell v2.1.0 before applying its QML customizations.'
    exit 1
fi
pending=()
for name in qt-6.10 hyprlock topbar topbar-frame topbar-no-top-edge launcher-super-jk; do
    change="$overrides/$name.patch"
    if patch --force --silent --dry-run -R -p1 -d "$shell_dir" < "$change" >/dev/null 2>&1; then
        continue
    fi
    # Check first, so a different upstream version never leaves a partial patch.
    patch --batch --forward --dry-run -p1 -d "$shell_dir" < "$change"
    pending+=("$change")
done
for change in "${pending[@]}"; do
    patch --batch --forward -p1 -d "$shell_dir" < "$change"
done
link_managed_path "$overrides/modules" "$shell_dir/modules/dotfiles"
print_success 'Caelestia QML customizations applied. Restart the shell to load them.'
