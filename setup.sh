#!/bin/bash

echo "🚀 Setting up dotfiles..."

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p ~/.config/nvim
mkdir -p ~/.config/nvim/dein
mkdir -p ~/.config/nvim/toml

# Backup existing files
if [ -f ~/.zshrc ]; then
  echo "📋 Backing up existing .zshrc..."
  cp ~/.zshrc ~/.zshrc.bak-$(date +%Y%m%d-%H%M%S)
fi

# Setup Zsh
echo "🐚 Setting up Zsh..."
touch ~/.zshrc
echo "# Source dotfiles zsh configuration" > ~/.zshrc
echo "if [ -f ~/.dotfiles/zsh/main.zsh ]; then" >> ~/.zshrc
echo "   source ~/.dotfiles/zsh/main.zsh" >> ~/.zshrc
echo "fi" >> ~/.zshrc

# Create symlinks
echo "🔗 Creating symlinks..."
ln -sf ~/.dotfiles/nvim/init.vim ~/.config/nvim/init.vim
ln -sf ~/.dotfiles/nvim/coc-settings.json ~/.config/nvim/coc-settings.json
ln -sf ~/.dotfiles/tmux/tmux.conf ~/.tmux.conf

# Check if dein.toml files exist (for backward compatibility)
if [ -f ~/.dotfiles/dein.toml ]; then
  ln -sf ~/.dotfiles/dein.toml ~/.config/nvim/toml/dein.toml
fi
if [ -f ~/.dotfiles/dein_lazy.toml ]; then
  ln -sf ~/.dotfiles/dein_lazy.toml ~/.config/nvim/toml/dein_lazy.toml
fi

# Install vim-plug for Neovim
echo "📦 Installing vim-plug..."
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
 https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

echo "✅ Setup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Restart your terminal or run: source ~/.zshrc"
echo "2. Open Neovim and run: :PlugInstall"
echo "3. Open tmux and press: Prefix + I (to install plugins)"
echo ""
echo "💡 Tip: Make sure you have Nerd Font installed for icons to display correctly"