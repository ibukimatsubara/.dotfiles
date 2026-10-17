#!/usr/bin/env bash
# Sourced by the root entry point.
platform_essentials=("zsh:zsh" "tmux:tmux" "mosh:mosh" "git:git" "jq:jq" "fzf:fzf" "zoxide:zoxide" "direnv:direnv" "ripgrep:rg" "fd-find:fdfind" "gh:gh" "wl-clipboard:wl-copy" "xclip:xclip" "curl:curl" "unzip:unzip" "build-essential:make")

check_package_manager() {
    command -v apt >/dev/null 2>&1 || { print_error "apt is required"; return 1; }
    sudo apt update
}

pkg_install() { sudo apt install -y "$1"; }

install_uv() { curl -LsSf https://astral.sh/uv/install.sh | sh; }

install_browser_runtime() { agent-browser install --with-deps; }

install_platform_tools() {
    print_info "Install VS Code, Chrome, Ghostty, and Nerd Fonts from their official distributions."
}
