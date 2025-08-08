#!/bin/bash

echo "🚀 Setting up dotfiles..."

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

# Create necessary directories
print_info "📁 Creating directories..."
mkdir -p ~/.config/nvim/plugin
mkdir -p ~/.config/nvim/undo
mkdir -p ~/.local/share/nvim/undo
mkdir -p ~/.local/share/nvim/session

# Backup existing files
backup_file() {
    if [ -f "$1" ] || [ -L "$1" ]; then
        local backup_name="$1.bak-$(date +%Y%m%d-%H%M%S)"
        print_warning "Backing up existing $1 to $backup_name"
        mv "$1" "$backup_name"
    fi
}

# Setup Zsh
print_info "🐚 Setting up Zsh..."
if [ -f ~/.zshrc ]; then
    # Check if our source line already exists
    if ! grep -q "source ~/.dotfiles/zsh/main.zsh" ~/.zshrc; then
        print_info "Adding dotfiles source to existing .zshrc..."
        echo "" >> ~/.zshrc
        echo "# Source dotfiles zsh configuration" >> ~/.zshrc
        echo "if [ -f ~/.dotfiles/zsh/main.zsh ]; then" >> ~/.zshrc
        echo "   source ~/.dotfiles/zsh/main.zsh" >> ~/.zshrc
        echo "fi" >> ~/.zshrc
    else
        print_success "Dotfiles already sourced in .zshrc"
    fi
else
    # Create new .zshrc
    echo "# Source dotfiles zsh configuration" > ~/.zshrc
    echo "if [ -f ~/.dotfiles/zsh/main.zsh ]; then" >> ~/.zshrc
    echo "   source ~/.dotfiles/zsh/main.zsh" >> ~/.zshrc
    echo "fi" >> ~/.zshrc
fi

# Create symlinks (with backup)
print_info "🔗 Creating symlinks..."

# Neovim config
backup_file ~/.config/nvim/init.vim
ln -sf ~/.dotfiles/nvim/init.vim ~/.config/nvim/init.vim
print_success "Linked init.vim"

# Link plugin directory
if [ -d ~/.dotfiles/nvim/plugin ]; then
    ln -sfn ~/.dotfiles/nvim/plugin ~/.config/nvim/plugin
    print_success "Linked plugin directory"
fi

# CoC settings (only if it exists)
if [ -f ~/.dotfiles/nvim/coc-settings.json ]; then
    backup_file ~/.config/nvim/coc-settings.json
    ln -sf ~/.dotfiles/nvim/coc-settings.json ~/.config/nvim/coc-settings.json
    print_success "Linked coc-settings.json"
fi

# tmux config
backup_file ~/.tmux.conf
ln -sf ~/.dotfiles/tmux/tmux.conf ~/.tmux.conf
print_success "Linked tmux.conf"


# Install vim-plug for Neovim if not already installed
if [ ! -f "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim" ]; then
    print_info "📦 Installing vim-plug..."
    sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
    print_success "vim-plug installed"
else
    print_success "vim-plug already installed"
fi

# Install Neovim plugins
print_info "📦 Installing Neovim plugins..."
nvim --headless +PlugInstall +qall 2>/dev/null && print_success "Neovim plugins installed" || print_warning "Please run :PlugInstall in Neovim"

print_success "✅ Setup complete!"
echo ""
print_info "📝 Next steps:"
echo "1. Restart your terminal or run: source ~/.zshrc"
echo "2. Open Neovim to verify the setup"
echo "3. Open tmux and press: Prefix + I (to install plugins)"
echo ""
print_info "💡 Tips:"
echo "- Previous configs are backed up with timestamp"
echo "- Run 'gcmc' for AI-powered git commits"
echo "- Neovim will auto-reload files changed by AI tools"