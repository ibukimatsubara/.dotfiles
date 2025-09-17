#!/bin/bash

echo "🔗 Setting up dotfiles configuration..."

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

# Check if we're on macOS
is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

# Create necessary directories
create_directories() {
    print_info "📁 Creating configuration directories..."

    # Neovim directories
    mkdir -p ~/.config/nvim/plugin
    mkdir -p ~/.config/nvim/undo
    mkdir -p ~/.local/share/nvim/undo
    mkdir -p ~/.local/share/nvim/session

    # macOS-specific directories
    if is_macos; then
        mkdir -p ~/.config/yabai
        mkdir -p ~/.config/skhd
        mkdir -p ~/.config/sketchybar
        mkdir -p ~/.config/borders
        mkdir -p ~/.config/kitty
    fi

    print_success "Directories created"
}

# Backup existing files
backup_file() {
    if [ -f "$1" ] || [ -L "$1" ]; then
        local backup_name="$1.bak-$(date +%Y%m%d-%H%M%S)"
        print_warning "Backing up existing $1 to $backup_name"
        mv "$1" "$backup_name"
    fi
}

# Setup Zsh configuration
setup_zsh() {
    print_info "🐚 Setting up Zsh configuration..."

    if [ -f ~/.zshrc ]; then
        # Check if our source line already exists
        if ! grep -q "source ~/.dotfiles/zsh/main.zsh" ~/.zshrc; then
            print_info "Adding dotfiles source to existing .zshrc..."
            echo "" >> ~/.zshrc
            echo "# Source dotfiles zsh configuration" >> ~/.zshrc
            echo "if [ -f ~/.dotfiles/zsh/main.zsh ]; then" >> ~/.zshrc
            echo "   source ~/.dotfiles/zsh/main.zsh" >> ~/.zshrc
            echo "fi" >> ~/.zshrc
            print_success "Added dotfiles source to .zshrc"
        else
            print_success "Dotfiles already sourced in .zshrc"
        fi
    else
        # Create new .zshrc
        echo "# Source dotfiles zsh configuration" > ~/.zshrc
        echo "if [ -f ~/.dotfiles/zsh/main.zsh ]; then" >> ~/.zshrc
        echo "   source ~/.dotfiles/zsh/main.zsh" >> ~/.zshrc
        echo "fi" >> ~/.zshrc
        print_success "Created new .zshrc with dotfiles source"
    fi
}

# Link Neovim configuration
link_neovim() {
    print_info "📝 Linking Neovim configuration..."

    # Main init.vim
    if [ -f ~/.dotfiles/nvim/init.vim ]; then
        backup_file ~/.config/nvim/init.vim
        ln -sf ~/.dotfiles/nvim/init.vim ~/.config/nvim/init.vim
        print_success "Linked init.vim"
    fi

    # Plugin directory
    if [ -d ~/.dotfiles/nvim/plugin ]; then
        backup_file ~/.config/nvim/plugin
        ln -sfn ~/.dotfiles/nvim/plugin ~/.config/nvim/plugin
        print_success "Linked plugin directory"
    fi

    # CoC settings (if exists)
    if [ -f ~/.dotfiles/nvim/coc-settings.json ]; then
        backup_file ~/.config/nvim/coc-settings.json
        ln -sf ~/.dotfiles/nvim/coc-settings.json ~/.config/nvim/coc-settings.json
        print_success "Linked coc-settings.json"
    fi
}

# Link tmux configuration
link_tmux() {
    print_info "🖥️  Linking tmux configuration..."

    if [ -f ~/.dotfiles/tmux/tmux.conf ]; then
        backup_file ~/.tmux.conf
        ln -sf ~/.dotfiles/tmux/tmux.conf ~/.tmux.conf
        print_success "Linked tmux.conf"
    else
        print_warning "tmux.conf not found in dotfiles"
    fi
}

# Link macOS window management configurations
link_macos_configs() {
    if ! is_macos; then
        print_info "Skipping macOS configurations (not on macOS)"
        return
    fi

    print_info "🪟 Linking macOS window management configurations..."

    # yabai configuration
    if [ -f ~/.dotfiles/yabairc ]; then
        backup_file ~/.config/yabai/yabairc
        ln -sf ~/.dotfiles/yabairc ~/.config/yabai/yabairc
        chmod +x ~/.config/yabai/yabairc
        print_success "Linked yabairc"
    else
        print_warning "yabairc not found in dotfiles"
    fi

    # skhd configuration
    if [ -f ~/.dotfiles/skhdrc ]; then
        backup_file ~/.config/skhd/skhdrc
        ln -sf ~/.dotfiles/skhdrc ~/.config/skhd/skhdrc
        print_success "Linked skhdrc"
    else
        print_warning "skhdrc not found in dotfiles"
    fi

    # SketchyBar configuration
    if [ -d ~/.dotfiles/sketchybar ]; then
        backup_file ~/.config/sketchybar
        ln -sf ~/.dotfiles/sketchybar ~/.config/sketchybar
        print_success "Linked SketchyBar configuration"

        # Make scripts executable
        chmod +x ~/.config/sketchybar/plugins/*.sh 2>/dev/null
        chmod +x ~/.config/sketchybar/items/*.sh 2>/dev/null
    else
        print_warning "SketchyBar config not found in dotfiles"
    fi

    # JankyBorders configuration
    if [ -f ~/.dotfiles/bordersrc ]; then
        backup_file ~/.config/borders/bordersrc
        ln -sf ~/.dotfiles/bordersrc ~/.config/borders/bordersrc
        chmod +x ~/.config/borders/bordersrc
        print_success "Linked JankyBorders configuration"
    else
        print_warning "JankyBorders config not found in dotfiles"
    fi

    # kitty configuration
    if [ -f ~/.dotfiles/kitty.conf ]; then
        backup_file ~/.config/kitty/kitty.conf
        ln -sf ~/.dotfiles/kitty.conf ~/.config/kitty/kitty.conf
        print_success "Linked kitty configuration"
    else
        print_warning "kitty.conf not found in dotfiles"
    fi
}

# Install Neovim plugins
install_neovim_plugins() {
    print_info "📦 Installing Neovim plugins..."

    # Check if vim-plug is installed
    if [ ! -f "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim" ]; then
        print_warning "vim-plug not found. Please run ./install.sh first"
        return
    fi

    # Install plugins
    if command -v nvim >/dev/null 2>&1; then
        nvim --headless +PlugInstall +qall 2>/dev/null && print_success "Neovim plugins installed" || print_warning "Please run :PlugInstall in Neovim"
    else
        print_warning "Neovim not found. Please run ./install.sh first"
    fi
}

# Setup assets (sounds, images, etc.)
setup_assets() {
    print_info "🔊 Setting up dotfiles assets..."

    # Create directories for SketchyBar assets
    mkdir -p ~/.config/sketchybar/assets/sounds

    # Copy Pomodoro timer sound
    if [ -f ~/.dotfiles/assets/sounds/kitchen-timer-5sec.mp3 ]; then
        cp ~/.dotfiles/assets/sounds/kitchen-timer-5sec.mp3 ~/.config/sketchybar/assets/sounds/
        print_success "Copied Pomodoro timer sound to ~/.config/sketchybar/assets/sounds/"
    else
        print_warning "Pomodoro timer sound not found in dotfiles"
    fi
}

# Check for required software
check_requirements() {
    print_info "🔍 Checking for required software..."

    local missing_tools=()
    local tools=("nvim" "tmux" "git")

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_warning "Missing required tools: ${missing_tools[*]}"
        print_info "Please run ./install.sh first to install required software"
        return 1
    fi

    print_success "All required tools are installed"
    return 0
}

# Main setup flow
main() {
    print_info "Starting dotfiles configuration setup..."
    echo ""

    # Check if required software is installed
    if ! check_requirements; then
        echo ""
        print_error "Please install required software first by running: ./install.sh"
        exit 1
    fi

    echo ""

    # Create directories
    create_directories
    echo ""

    # Setup configurations
    setup_zsh
    echo ""

    link_neovim
    echo ""

    link_tmux
    echo ""

    link_macos_configs
    echo ""

    setup_assets
    echo ""

    install_neovim_plugins
    echo ""

    print_success "✅ Dotfiles configuration setup complete!"
    echo ""
    print_info "📝 Next steps:"
    echo "1. Restart your terminal or run: source ~/.zshrc"
    echo "2. Open tmux and press: Prefix + I (to install tmux plugins)"
    echo "3. Open Neovim to verify the setup"

    if is_macos; then
        echo ""
        print_info "🍎 macOS users:"
        echo "- Consider enabling window management services:"
        echo "  • brew services start yabai"
        echo "  • brew services start skhd"
        echo "  • brew services start felixkratz/formulae/sketchybar"
        echo "  • Run 'borders &' to start JankyBorders"
    fi

    echo ""
    print_info "💡 Tips:"
    echo "- Previous configs are backed up with timestamp"
    echo "- Run 'gcmc' for AI-powered git commits"
    echo "- Neovim will auto-reload files changed by AI tools"
}

# Run main function
main "$@"