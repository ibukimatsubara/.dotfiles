#!/usr/bin/env bash
# Sourced by the root entry point.
platform_essentials=("tmux:tmux" "mosh:mosh" "media-control:media-control" "mpd:mpd" "rmpc:rmpc" "rsync:rsync" "git:git" "jq:jq" "fzf:fzf" "zoxide:zoxide" "direnv:direnv" "ripgrep:rg" "gh:gh" "fnm:fnm")

check_package_manager() {
    if ! command -v brew >/dev/null 2>&1; then
        print_error "Homebrew is not installed. Install it from https://brew.sh"
        return 1
    fi
    print_info "Updating Homebrew..."
    brew update
}

pkg_install() { brew install "$1"; }

install_uv() { brew install uv; }

install_browser_runtime() { agent-browser install; }

install_desktop_apps() {
    print_info "🖥️ Installing desktop development apps..."

    local desktop_casks=(
        "ghostty"
        "visual-studio-code"
        "google-chrome"
        "hammerspoon"
        "tailscale-app"
        "codex"
        "shottr"
    )

    for cask in "${desktop_casks[@]}"; do
        if [ "$cask" = "tailscale-app" ] && [ -d /Applications/Tailscale.app ]; then
            print_success "$cask already installed"
        elif brew list --cask "$cask" >/dev/null 2>&1; then
            print_success "$cask already installed"
        elif brew install --cask "$cask" >/dev/null 2>&1; then
            print_success "$cask installed"
        else
            print_warning "Failed to install $cask; it may already exist outside Homebrew"
        fi
    done

    if ! brew tap | grep -Fxq "nikitabobko/tap"; then
        print_info "Adding AeroSpace Homebrew tap..."
        if brew tap nikitabobko/tap >/dev/null 2>&1; then
            print_success "AeroSpace Homebrew tap added"
        else
            print_warning "Failed to add AeroSpace Homebrew tap"
        fi
    fi

    # Limit third-party trust to the AeroSpace cask rather than the whole tap.
    brew trust --cask nikitabobko/tap/aerospace >/dev/null 2>&1

    if brew list --cask aerospace >/dev/null 2>&1; then
        print_success "aerospace already installed"
    elif brew install --cask nikitabobko/tap/aerospace >/dev/null 2>&1; then
        print_success "aerospace installed"
    else
        print_warning "Failed to install aerospace"
    fi
}

install_fonts() {
    print_info "🔤 Installing Nerd Fonts..."
    local font
    for font in font-jetbrains-mono-nerd-font font-hack-nerd-font; do
        if brew list --cask "$font" >/dev/null 2>&1; then
            print_success "$font already installed"
        elif brew install --cask "$font"; then
            print_success "$font installed"
        else
            print_warning "Failed to install $font"
        fi
    done
}

install_macos_tools() {
    print_info "⌨️ Installing macOS hotkey tools..."

    if ! brew tap | grep -Fxq "FelixKratz/formulae"; then
        print_info "Adding FelixKratz Homebrew tap..."
        if brew tap FelixKratz/formulae >/dev/null 2>&1; then
            print_success "FelixKratz Homebrew tap added"
        else
            print_warning "Failed to add FelixKratz Homebrew tap"
        fi
    fi

    # Homebrew requires explicit trust before installing formulae from a
    # third-party tap. Limit that trust to the required formulae.
    brew trust --formula FelixKratz/formulae/borders >/dev/null 2>&1
    brew trust --formula FelixKratz/formulae/sketchybar >/dev/null 2>&1

    local macos_tools=("skhd" "borders" "sketchybar")

    for tool in "${macos_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            print_info "Installing $tool..."
            brew install "$tool" >/dev/null 2>&1
            print_success "$tool installed"
        else
            print_success "$tool already installed"
        fi
    done
}

install_platform_tools() {
    if ! command -v cliamp >/dev/null 2>&1; then
        brew tap bjarneo/cliamp || return 1
        brew trust --formula bjarneo/cliamp/cliamp || return 1
        brew install bjarneo/cliamp/cliamp || return 1
    fi
    install_desktop_apps
    install_fonts
    install_macos_tools
}
