#!/bin/bash

# Alacritty Icon Restorer
# Restores the original Alacritty icon

ALACRITTY_APP="/Applications/Alacritty.app"
BACKUP_ICON="$HOME/.dotfiles/assets/backups/alacritty-original.icns"

# 色付き出力用の関数
print_info() {
    echo -e "\033[34m$1\033[0m"
}

print_success() {
    echo -e "\033[32m✓ $1\033[0m"
}

print_error() {
    echo -e "\033[31m✗ $1\033[0m"
}

# Check if backup exists
if [ ! -f "$BACKUP_ICON" ]; then
    print_error "Original icon backup not found: $BACKUP_ICON"
    exit 1
fi

print_info "🔄 Restoring original Alacritty icon..."

# Restore the original icon
ORIGINAL_ICON="$ALACRITTY_APP/Contents/Resources/alacritty.icns"
sudo cp "$BACKUP_ICON" "$ORIGINAL_ICON"

# Clear icon cache and refresh
print_info "Refreshing icon cache..."
touch "$ALACRITTY_APP"
sudo killall Finder 2>/dev/null
sudo killall Dock 2>/dev/null

print_success "✨ Original Alacritty icon restored!"