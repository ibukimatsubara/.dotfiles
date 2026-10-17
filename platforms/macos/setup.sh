#!/usr/bin/env bash
# Sourced by the root entry point.

start_hammerspoon() {
    if open -g -a Hammerspoon >/dev/null 2>&1; then
        print_success "Hammerspoon started (managed config enables launch on login)"
        if command -v hs >/dev/null 2>&1; then
            if hs -A -t 3 -c 'hs.timer.doAfter(0.1, hs.reload); return true' </dev/null >/dev/null 2>&1; then
                print_success "Hammerspoon configuration reload scheduled"
            else
                print_warning "Reload Configuration from the Hammerspoon menu to apply the linked config."
            fi
        else
            print_warning "Hammerspoon CLI is unavailable. Reload Configuration from the Hammerspoon menu."
        fi
        print_info "Allow Hammerspoon in System Settings > Privacy & Security > Accessibility, then relaunch it if needed."
    else
        print_warning "Hammerspoon could not start. Install with: brew install --cask hammerspoon"
    fi
}

link_macos_configs() {
    print_info "🍎 Linking macOS configurations..."

    # skhd configuration (skhd reads ~/.skhdrc by default)
    if [ -f ~/.dotfiles/skhdrc ]; then
        backup_file ~/.skhdrc
        ln -sf ~/.dotfiles/skhdrc ~/.skhdrc
        print_success "Linked skhdrc"
    else
        print_warning "skhdrc not found in dotfiles"
    fi

    # kitty configuration
    if [ -f ~/.dotfiles/kitty.conf ]; then
        backup_file ~/.config/kitty/kitty.conf
        ln -sf ~/.dotfiles/kitty.conf ~/.config/kitty/kitty.conf
        print_success "Linked kitty configuration"
    else
        print_warning "kitty.conf not found in dotfiles"
    fi

    # kitty color theme link (defaults to dark)
    if [ -f ~/.dotfiles/kitty/colors/dark.conf ]; then
        backup_file ~/.config/kitty/theme.conf
        ln -sf ~/.dotfiles/kitty/colors/dark.conf ~/.config/kitty/theme.conf
        print_success "Linked kitty default theme (dark)"
    else
        print_warning "kitty dark theme definition not found"
    fi

    # JankyBorders configuration
    if [ -f ~/.dotfiles/borders/bordersrc ]; then
        link_managed_path \
            "$HOME/.dotfiles/borders/bordersrc" \
            "$HOME/.config/borders/bordersrc"
    else
        print_warning "JankyBorders config not found in dotfiles"
    fi

    # AeroSpace configuration
    if [ -f ~/.dotfiles/aerospace/aerospace.toml ]; then
        link_managed_path \
            "$HOME/.dotfiles/aerospace/aerospace.toml" \
            "$HOME/.config/aerospace/aerospace.toml"
    else
        print_warning "AeroSpace config not found in dotfiles"
    fi

    # SketchyBar configuration
    if [ -d ~/.dotfiles/sketchybar ]; then
        link_managed_path \
            "$HOME/.dotfiles/sketchybar" \
            "$HOME/.config/sketchybar"
    else
        print_warning "SketchyBar config not found in dotfiles"
    fi

    # Hammerspoon configuration
    if [ -f ~/.dotfiles/hammerspoon/init.lua ]; then
        mkdir -p ~/.hammerspoon
        backup_file ~/.hammerspoon/init.lua
        ln -sf ~/.dotfiles/hammerspoon/init.lua ~/.hammerspoon/init.lua
        print_success "Linked Hammerspoon configuration"
    else
        print_warning "Hammerspoon config not found in dotfiles"
    fi

    # Break timer configuration (Ghostty shader + Hammerspoon)
    if [ -f ~/.dotfiles/break-timer/config.lua ]; then
        mkdir -p ~/.config/break-timer
        backup_file ~/.config/break-timer/config.lua
        ln -sf ~/.dotfiles/break-timer/config.lua ~/.config/break-timer/config.lua
        print_success "Linked break-timer configuration"
    else
        print_warning "break-timer config not found in dotfiles"
    fi
}

apply_aqua_voice_settings() {
    print_info "🎙️  Applying Aqua Voice settings..."

    if [ ! -x "$HOME/.dotfiles/scripts/apply-aqua-voice-settings.sh" ]; then
        print_warning "Aqua Voice settings helper not found"
        return
    fi

    if "$HOME/.dotfiles/scripts/apply-aqua-voice-settings.sh"; then
        print_success "Aqua Voice settings applied"
    else
        print_warning "Aqua Voice settings skipped; quit the app and rerun setup if needed"
    fi
}

setup_tmux_pane_summaries() {
    print_info "🧠 Setting up hourly tmux pane summaries..."

    if ! command -v codex >/dev/null 2>&1; then
        print_warning "Codex CLI not found; skipping tmux pane summaries"
        return
    fi

    if ~/.dotfiles/scripts/setup-tmux-pane-summaries.sh; then
        print_success "Hourly tmux pane summaries enabled"
    else
        print_warning "Failed to enable hourly tmux pane summaries"
    fi
}

vscode_config_dir() { printf '%s/Library/Application Support/Code/User\n' "$HOME"; }

start_platform_services() {
    print_info "🍎 Starting macOS services..."
    start_hammerspoon

    # skhd
    if command -v skhd >/dev/null 2>&1; then
        skhd --start-service 2>/dev/null
        print_success "skhd service started (auto-starts on login)"
    else
        print_warning "skhd not found. Install with: brew install koekeishiya/formulae/skhd"
    fi

    # JankyBorders
    if command -v borders >/dev/null 2>&1; then
        if brew services start borders >/dev/null 2>&1; then
            print_success "JankyBorders service started (auto-starts on login)"
        else
            print_warning "Failed to start JankyBorders service"
        fi
    else
        print_warning "JankyBorders not found. Install with: brew install FelixKratz/formulae/borders"
    fi

    # SketchyBar
    if command -v sketchybar >/dev/null 2>&1; then
        if brew services start sketchybar >/dev/null 2>&1; then
            print_success "SketchyBar service started (auto-starts on login)"
        else
            print_warning "Failed to start SketchyBar service"
        fi
    else
        print_warning "SketchyBar not found. Install with: brew install FelixKratz/formulae/sketchybar"
    fi

    # AeroSpace
    if command -v aerospace >/dev/null 2>&1; then
        open -a AeroSpace
        print_success "AeroSpace started (auto-starts on login)"
    else
        print_warning "AeroSpace not found. Install with: brew install --cask nikitabobko/tap/aerospace"
    fi
}

setup_platform() {
    mkdir -p "$HOME/.config/"{skhd,kitty,borders,aerospace,sketchybar}
    link_macos_configs
    apply_aqua_voice_settings
    setup_tmux_pane_summaries
    start_platform_services
}

ghostty_config_source() { printf '%s/ghostty/config\n' "$DOTFILES_ROOT"; }
