#!/usr/bin/env bash
# Explicit opt-in desktop installation; never switches the current session.
set -euo pipefail
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$DOTFILES_ROOT/platforms/common/lib.sh"
. /etc/os-release
if [ "${ID:-}" != ubuntu ] || [ "${VERSION_ID:-}" != 26.04 ]; then
    print_error 'This desktop installer targets Ubuntu 26.04.'
    exit 1
fi
sudo -v
for ppa in danklinux dms; do
    if ! grep -Rqs "ppa.launchpadcontent.net/avengemedia/$ppa/ubuntu" /etc/apt/sources.list.d; then
        sudo add-apt-repository --no-update -y "ppa:avengemedia/$ppa"
    fi
done
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    hyprland dms hypridle hyprlock xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk fcitx5 fcitx5-mozc fcitx5-config-qt \
    fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt6 \
    grim slurp swappy fuzzel playerctl pavucontrol xwayland jq wl-clipboard \
    python3 pipewire-bin libnotify-bin curl ca-certificates
if ! command -v vicinae >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/vicinae" ]; then
    installer="$(mktemp)"
    trap 'rm -f "$installer"' EXIT
    curl -fsSL https://vicinae.com/install -o "$installer"
    bash "$installer" --prefix "$HOME/.local"
fi
bash "$DOTFILES_ROOT/platforms/ubuntu/setup-desktop.sh"
systemctl --user daemon-reload
print_success 'Desktop installed. Log out and select Hyprland when ready.'
