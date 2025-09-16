#!/bin/bash

# Alacritty Icon Changer
# Usage: ./change-alacritty-icon.sh [icon-file.icns]

ICON_FILE="${1:-$HOME/.dotfiles/assets/alacritty-bigsur.icns}"
ALACRITTY_APP="/Applications/Alacritty.app"
BACKUP_DIR="$HOME/.dotfiles/assets/backups"

# 色付き出力用の関数
print_info() {
    echo -e "\033[34m$1\033[0m"
}

print_success() {
    echo -e "\033[32m✓ $1\033[0m"
}

print_warning() {
    echo -e "\033[33m⚠ $1\033[0m"
}

print_error() {
    echo -e "\033[31m✗ $1\033[0m"
}

# Check if Alacritty is installed
if [ ! -d "$ALACRITTY_APP" ]; then
    print_error "Alacritty not found at $ALACRITTY_APP"
    exit 1
fi

# Check if icon file exists
if [ ! -f "$ICON_FILE" ]; then
    print_error "Icon file not found: $ICON_FILE"
    print_info "Usage: $0 [path-to-icon.icns]"
    exit 1
fi

print_info "🎨 Changing Alacritty icon..."

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup original icon (if not already backed up)
ORIGINAL_ICON="$ALACRITTY_APP/Contents/Resources/alacritty.icns"
BACKUP_ICON="$BACKUP_DIR/alacritty-original.icns"

if [ ! -f "$BACKUP_ICON" ]; then
    print_info "Backing up original icon..."
    cp "$ORIGINAL_ICON" "$BACKUP_ICON"
    print_success "Original icon backed up"
fi

# Replace the icon
print_info "Replacing icon..."
sudo cp "$ICON_FILE" "$ORIGINAL_ICON"

# Clear icon cache and refresh
print_info "Refreshing icon cache..."
touch "$ALACRITTY_APP"
sudo killall Finder 2>/dev/null
sudo killall Dock 2>/dev/null

print_success "✨ Alacritty icon changed successfully!"
print_info "💡 Note: Icon will be reset when Alacritty updates"
print_info "📁 Original icon backed up to: $BACKUP_ICON"