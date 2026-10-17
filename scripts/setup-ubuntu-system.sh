#!/usr/bin/env bash
# Run as the desktop user in a terminal so sudo can request authentication.
set -euo pipefail
sudo apt update
sudo apt install -y zsh tmux fzf zoxide direnv wl-clipboard ripgrep fd-find unzip build-essential
sudo chsh -s /usr/bin/zsh "$(id -un)"
mkdir -p "$HOME/.cache/ubuntu-dotfiles-setup"
touch "$HOME/.cache/ubuntu-dotfiles-setup/system-complete"
echo 'Ubuntu packages and login shell are configured.'
