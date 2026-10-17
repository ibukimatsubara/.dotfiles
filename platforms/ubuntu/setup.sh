#!/usr/bin/env bash
# Sourced by the root entry point.

vscode_config_dir() { printf '%s/Code/User\n' "${XDG_CONFIG_HOME:-$HOME/.config}"; }

setup_platform() {
    print_info "Ubuntu profile configured (Wayland/X11 clipboard, Ghostty, Zsh)."
}

ghostty_config_source() { printf '%s/ghostty/config-linux\n' "$DOTFILES_ROOT"; }
