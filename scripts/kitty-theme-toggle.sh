#!/bin/bash

set -euo pipefail

# Emoji friendly logging helpers
print_info() {
    echo -e "\033[34mℹ $1\033[0m"
}

print_success() {
    echo -e "\033[32m✓ $1\033[0m"
}

print_warning() {
    echo -e "\033[33m⚠ $1\033[0m"
}

print_error() {
    echo -e "\033[31m✗ $1\033[0m" >&2
}

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
THEME_DIR="$DOTFILES_DIR/kitty/colors"
THEME_LINK="$HOME/.config/kitty/theme.conf"
DEFAULT_THEME="dark"

usage() {
    cat <<USAGE
Kitty theme toggle

Usage: $(basename "$0") [dark|light|white|status]
       $(basename "$0")           # toggle between light/dark

Options:
  dark      Force dark theme
  light     Force light theme
  white     Alias for light theme
  status    Print current theme and exit
USAGE
}

ensure_theme_dir() {
    if [ ! -d "$THEME_DIR" ]; then
        print_error "Theme directory not found: $THEME_DIR"
        exit 1
    fi
}

ensure_theme_link() {
    if [ ! -e "$THEME_LINK" ]; then
        local default_file="$THEME_DIR/${DEFAULT_THEME}.conf"
        if [ -f "$default_file" ]; then
            mkdir -p "$(dirname "$THEME_LINK")"
            ln -sf "$default_file" "$THEME_LINK"
            print_warning "No existing theme.conf found. Defaulting to $DEFAULT_THEME"
        else
            print_error "Default theme file missing: $default_file"
            exit 1
        fi
    fi
}

current_theme() {
    if [ -L "$THEME_LINK" ]; then
        local link_target
        link_target=$(readlink "$THEME_LINK")
        basename "$link_target" .conf 2>/dev/null || true
    elif [ -f "$THEME_LINK" ]; then
        # Attempt to detect by matching checksum against known files
        local checksum file hash_cmd
        if command -v shasum >/dev/null 2>&1; then
            hash_cmd="shasum"
        else
            hash_cmd="cksum"
        fi

        checksum=$($hash_cmd "$THEME_LINK" | awk '{print $1}')
        for file in "$THEME_DIR"/*.conf; do
            if [ -f "$file" ]; then
                if [ "$checksum" == "$($hash_cmd "$file" | awk '{print $1}')" ]; then
                    basename "$file" .conf
                    return
                fi
            fi
        done
        echo "custom"
    else
        echo "$DEFAULT_THEME"
    fi
}

reload_kitty() {
    if pgrep -x kitty >/dev/null 2>&1; then
        if pkill -USR1 -x kitty >/dev/null 2>&1; then
            print_info "Reloaded Kitty with new theme"
        else
            print_warning "Failed to signal Kitty; restart manually"
        fi
    else
        print_warning "Kitty not running; change takes effect next launch"
    fi
}

apply_theme() {
    local theme="$1"
    local source_file="$THEME_DIR/${theme}.conf"

    if [ ! -f "$source_file" ]; then
        print_error "Unknown theme: $theme"
        exit 1
    fi

    mkdir -p "$(dirname "$THEME_LINK")"
    ln -sf "$source_file" "$THEME_LINK"
    print_success "Switched Kitty theme to $theme"
    reload_kitty
}

ensure_theme_dir
ensure_theme_link

if [ $# -gt 1 ]; then
    usage
    exit 1
fi

action="${1:-toggle}"
case "$action" in
    dark)
        apply_theme "dark"
        ;;
    light|white)
        apply_theme "light"
        ;;
    status)
        theme=$(current_theme)
        print_info "Current Kitty theme: $theme"
        exit 0
        ;;
    toggle)
        theme=$(current_theme)
        if [ "$theme" == "light" ]; then
            apply_theme "dark"
        else
            apply_theme "light"
        fi
        ;;
    -h|--help)
        usage
        ;;
    *)
        print_error "Unknown argument: $action"
        usage
        exit 1
        ;;
	esac
