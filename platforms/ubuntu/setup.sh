#!/usr/bin/env bash
# Sourced by the root entry point.

vscode_config_dir() { printf '%s/Code/User\n' "${XDG_CONFIG_HOME:-$HOME/.config}"; }

setup_platform() {
    if command -v mpd >/dev/null 2>&1 && command -v systemctl >/dev/null 2>&1; then
        if systemctl --user daemon-reload && \
           systemctl --user enable --now dotfiles-mpd.service; then
            print_success "MPD user service enabled"
        else
            print_warning "MPD needs a desktop user session. Run: systemctl --user enable --now dotfiles-mpd.service"
        fi
    else
        print_warning "Install MPD and start a systemd user session to enable music playback"
    fi
    print_info "Ubuntu profile configured (Wayland/X11 clipboard, Ghostty, Zsh)."
}

ghostty_config_source() { printf '%s/ghostty/config-linux\n' "$DOTFILES_ROOT"; }
