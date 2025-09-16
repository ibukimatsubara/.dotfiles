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

# yabai config (if on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    print_info "🪟 Setting up yabai window manager..."

    # Check if yabai is installed
    if ! command -v yabai >/dev/null 2>&1; then
        print_warning "yabai is not installed. Please install with: brew install koekeishiya/formulae/yabai"
    else
        backup_file ~/.config/yabai/yabairc
        mkdir -p ~/.config/yabai
        ln -sf ~/.dotfiles/yabairc ~/.config/yabai/yabairc
        chmod +x ~/.config/yabai/yabairc
        print_success "Linked yabairc"
    fi

    # skhd config
    print_info "⌨️  Setting up skhd hotkey daemon..."

    # Check if skhd is installed
    if ! command -v skhd >/dev/null 2>&1; then
        print_warning "skhd is not installed. Please install with: brew install koekeishiya/formulae/skhd"
    else
        backup_file ~/.config/skhd/skhdrc
        mkdir -p ~/.config/skhd
        ln -sf ~/.dotfiles/skhdrc ~/.config/skhd/skhdrc
        print_success "Linked skhdrc"
    fi
else
    print_info "Skipping yabai/skhd setup (macOS only)"
fi

# Setup Kitty (if installed)
if command -v kitty >/dev/null 2>&1; then
    print_info "🐱 Setting up Kitty terminal..."
    
    # Create kitty config directory if it doesn't exist
    mkdir -p ~/.config/kitty
    
    # Check if kitty-themes is already installed
    if [ ! -d ~/.config/kitty/kitty-themes ]; then
        print_info "Installing kitty-themes..."
        git clone https://github.com/dexpota/kitty-themes.git ~/.config/kitty/kitty-themes >/dev/null 2>&1
        print_success "kitty-themes installed"
    else
        print_success "kitty-themes already installed"
    fi
    
    # Check if theme is already configured
    if [ -f ~/.config/kitty/kitty.conf ]; then
        if ! grep -q "include ./kitty-themes/themes/" ~/.config/kitty/kitty.conf; then
            print_info "Adding Dracula theme to kitty.conf..."
            echo "" >> ~/.config/kitty/kitty.conf
            echo "# Theme" >> ~/.config/kitty/kitty.conf
            echo "include ./kitty-themes/themes/Dracula.conf" >> ~/.config/kitty/kitty.conf
            print_success "Dracula theme configured"
        else
            print_success "Kitty theme already configured"
        fi
    fi
else
    print_info "Kitty not found, skipping Kitty setup"
fi

# Setup SketchyBar (if on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    print_info "📊 Setting up SketchyBar..."
    
    # Check if SketchyBar is installed
    if ! command -v sketchybar >/dev/null 2>&1; then
        print_info "Installing SketchyBar..."
        brew tap FelixKratz/formulae >/dev/null 2>&1
        brew install sketchybar >/dev/null 2>&1
        print_success "SketchyBar installed"
    else
        print_success "SketchyBar already installed"
    fi
    
    # Install required fonts for SketchyBar
    print_info "Installing JetBrainsMono Nerd Font..."
    if ! brew list --cask | grep -q "font-jetbrains-mono-nerd-font"; then
        brew install --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1
        print_success "JetBrainsMono Nerd Font installed"
    else
        print_success "JetBrainsMono Nerd Font already installed"
    fi
    
    # Create symlink for SketchyBar config if it exists in dotfiles
    if [ -d ~/.dotfiles/sketchybar ]; then
        backup_file ~/.config/sketchybar
        ln -sf ~/.dotfiles/sketchybar ~/.config/sketchybar
        print_success "Linked SketchyBar configuration"
        
        # Make scripts executable
        chmod +x ~/.config/sketchybar/plugins/*.sh 2>/dev/null
        chmod +x ~/.config/sketchybar/items/*.sh 2>/dev/null
        
        # Start SketchyBar service if not running
        if ! brew services list | grep -q "sketchybar.*started"; then
            brew services start felixkratz/formulae/sketchybar >/dev/null 2>&1
            print_success "SketchyBar service started"
        else
            # Reload configuration
            sketchybar --reload >/dev/null 2>&1
            print_success "SketchyBar configuration reloaded"
        fi
    else
        print_warning "SketchyBar config not found in dotfiles"
    fi
else
    print_info "Skipping SketchyBar setup (macOS only)"
fi

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

# Check for uv Python package manager
print_info "🐍 Checking Python environment..."
if command -v uv >/dev/null 2>&1; then
    print_success "uv is installed ($(uv --version))"
else
    print_warning "uv is not installed - recommended for Python development"
    echo "Install with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo "Or via Homebrew: brew install uv"
fi

print_success "✅ Setup complete!"
echo ""
print_info "📝 Next steps:"
echo "1. Restart your terminal or run: source ~/.zshrc"
echo "2. Open Neovim to verify the setup"
echo "3. Open tmux and press: Prefix + I (to install plugins)"
if ! command -v uv >/dev/null 2>&1; then
    echo "4. Install uv for better Python development experience"
fi
echo ""
print_info "💡 Tips:"
echo "- Previous configs are backed up with timestamp"
echo "- Run 'gcmc' for AI-powered git commits"
echo "- Neovim will auto-reload files changed by AI tools"
echo "- Use 'uvr python script.py' to run Python with uv"