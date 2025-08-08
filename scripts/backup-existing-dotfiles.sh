#!/bin/bash

# 完全バックアップスクリプト for SSH先での安全な置換
# Usage: ./backup-existing-dotfiles.sh

set -e

BACKUP_DIR="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$BACKUP_DIR/backup.log"

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

# バックアップディレクトリ作成
print_info "Creating backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# ログ開始
echo "Dotfiles backup started at $(date)" > "$LOG_FILE"
echo "Backup directory: $BACKUP_DIR" >> "$LOG_FILE"
echo "---" >> "$LOG_FILE"

# バックアップ対象ファイル・ディレクトリのリスト
BACKUP_TARGETS=(
    "$HOME/.zshrc"
    "$HOME/.bashrc"
    "$HOME/.bash_profile"
    "$HOME/.profile"
    "$HOME/.vimrc"
    "$HOME/.tmux.conf"
    "$HOME/.gitconfig"
    "$HOME/.ssh/config"
    "$HOME/.config"
    "$HOME/.vim"
    "$HOME/.tmux"
    "$HOME/.dotfiles"
    "$HOME/.oh-my-zsh"
    "$HOME/.zsh"
    "$HOME/.local/share/nvim"
)

# 各ファイル・ディレクトリをバックアップ
for target in "${BACKUP_TARGETS[@]}"; do
    if [ -e "$target" ] || [ -L "$target" ]; then
        basename_target=$(basename "$target")
        print_info "Backing up: $target"
        
        if [ -d "$target" ]; then
            cp -r "$target" "$BACKUP_DIR/$basename_target" 2>/dev/null && {
                print_success "Backed up directory: $basename_target"
                echo "✓ $target -> $BACKUP_DIR/$basename_target" >> "$LOG_FILE"
            } || {
                print_warning "Failed to backup directory: $target"
                echo "✗ Failed: $target" >> "$LOG_FILE"
            }
        else
            cp "$target" "$BACKUP_DIR/$basename_target" 2>/dev/null && {
                print_success "Backed up file: $basename_target"
                echo "✓ $target -> $BACKUP_DIR/$basename_target" >> "$LOG_FILE"
            } || {
                print_warning "Failed to backup file: $target"
                echo "✗ Failed: $target" >> "$LOG_FILE"
            }
        fi
    else
        echo "- Not found: $target" >> "$LOG_FILE"
    fi
done

# システム情報も保存
print_info "Saving system information..."
{
    echo "=== SYSTEM INFO ==="
    echo "Date: $(date)"
    echo "User: $(whoami)"
    echo "Home: $HOME"
    echo "Shell: $SHELL"
    echo "OS: $(uname -a)"
    echo ""
    echo "=== ENVIRONMENT ==="
    env | sort
    echo ""
    echo "=== INSTALLED PACKAGES (if available) ==="
    which brew >/dev/null && brew list 2>/dev/null || echo "Homebrew not found"
    which apt >/dev/null && apt list --installed 2>/dev/null | head -20 || echo "apt not found"
    which yum >/dev/null && yum list installed 2>/dev/null | head -20 || echo "yum not found"
} >> "$BACKUP_DIR/system-info.txt"

# 権限情報も保存
print_info "Saving file permissions..."
find "$HOME" -maxdepth 2 -name ".*" -exec ls -la {} \; 2>/dev/null > "$BACKUP_DIR/permissions.txt" || true

print_success "✅ Backup completed successfully!"
echo ""
print_info "📁 Backup location: $BACKUP_DIR"
print_info "📝 Log file: $LOG_FILE"
echo ""
print_info "💡 To restore, run:"
echo "   ./restore-dotfiles.sh $BACKUP_DIR"
echo ""

# バックアップ完了をログに記録
echo "---" >> "$LOG_FILE"
echo "Backup completed successfully at $(date)" >> "$LOG_FILE"

# バックアップサマリーを表示
echo "=== BACKUP SUMMARY ===" 
ls -la "$BACKUP_DIR"