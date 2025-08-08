#!/bin/bash

# 復元スクリプト - バックアップから元の状態に戻す
# Usage: ./restore-dotfiles.sh <backup_directory>

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <backup_directory>"
    echo "Example: $0 ~/dotfiles-backup-20250808-123456"
    exit 1
fi

BACKUP_DIR="$1"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: Backup directory $BACKUP_DIR does not exist"
    exit 1
fi

# 色付き出力用の関数
print_info() {
    echo -e "\033[34m[INFO] $1\033[0m"
}

print_success() {
    echo -e "\033[32m[SUCCESS] $1\033[0m"
}

print_warning() {
    echo -e "\033[33m[WARNING] $1\033[0m"
}

print_error() {
    echo -e "\033[31m[ERROR] $1\033[0m"
}

print_warning "⚠️  This will OVERWRITE your current dotfiles configuration!"
print_info "Backup directory: $BACKUP_DIR"
echo ""
read -p "Are you sure you want to restore? (y/N): " confirm

if [[ $confirm != [yY] ]]; then
    print_info "Restore cancelled."
    exit 0
fi

print_info "🔄 Starting restoration from $BACKUP_DIR..."

# 現在の設定を削除（新しいdotfilesを削除）
print_info "Removing current dotfiles configuration..."
rm -rf "$HOME/.dotfiles" 2>/dev/null || true
rm -f "$HOME/.zshrc" 2>/dev/null || true
rm -f "$HOME/.tmux.conf" 2>/dev/null || true
rm -rf "$HOME/.config/nvim" 2>/dev/null || true

# バックアップから復元
print_info "Restoring files from backup..."
cd "$BACKUP_DIR"

for item in *; do
    if [ "$item" != "backup.log" ] && [ "$item" != "system-info.txt" ] && [ "$item" != "permissions.txt" ]; then
        target="$HOME/.$item"
        print_info "Restoring: $item -> $target"
        
        if [ -d "$item" ]; then
            cp -r "$item" "$target" && print_success "✓ Restored directory: $item"
        else
            cp "$item" "$target" && print_success "✓ Restored file: $item"
        fi
    fi
done

print_success "✅ Restoration completed!"
print_info "💡 Please restart your terminal or run: source ~/.zshrc"