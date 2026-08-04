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
        mkdir -p ~/.config/skhd
        mkdir -p ~/.config/kitty
        mkdir -p ~/.config/ghostty
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

    # Main init.lua (Lazy.nvim)
    if [ -f ~/.dotfiles/nvim/init.lua ]; then
        backup_file ~/.config/nvim/init.lua
        ln -sf ~/.dotfiles/nvim/init.lua ~/.config/nvim/init.lua
        print_success "Linked init.lua"
    fi

    # Lua configuration directory
    if [ -d ~/.dotfiles/nvim/lua ]; then
        backup_file ~/.config/nvim/lua
        ln -sfn ~/.dotfiles/nvim/lua ~/.config/nvim/lua
        print_success "Linked lua directory"
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

    # Install TPM (Tmux Plugin Manager)
    if [ ! -d ~/.tmux/plugins/tpm ]; then
        print_info "Installing TPM (Tmux Plugin Manager)..."
        if git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm 2>/dev/null; then
            print_success "TPM installed"
        else
            print_warning "Failed to install TPM"
        fi
    else
        print_success "TPM already installed"
    fi
}

# Link macOS configurations
link_macos_configs() {
    if ! is_macos; then
        print_info "Skipping macOS configurations (not on macOS)"
        return
    fi

    print_info "🍎 Linking macOS configurations..."

    # skhd configuration (skhd reads ~/.skhdrc by default)
    if [ -f ~/.dotfiles/skhdrc ]; then
        backup_file ~/.skhdrc
        ln -sf ~/.dotfiles/skhdrc ~/.skhdrc
        print_success "Linked skhdrc"
    else
        print_warning "skhdrc not found in dotfiles"
    fi

    # kitty configuration
    if [ -f ~/.dotfiles/kitty.conf ]; then
        backup_file ~/.config/kitty/kitty.conf
        ln -sf ~/.dotfiles/kitty.conf ~/.config/kitty/kitty.conf
        print_success "Linked kitty configuration"
    else
        print_warning "kitty.conf not found in dotfiles"
    fi

    # kitty color theme link (defaults to dark)
    if [ -f ~/.dotfiles/kitty/colors/dark.conf ]; then
        backup_file ~/.config/kitty/theme.conf
        ln -sf ~/.dotfiles/kitty/colors/dark.conf ~/.config/kitty/theme.conf
        print_success "Linked kitty default theme (dark)"
    else
        print_warning "kitty dark theme definition not found"
    fi

    # Ghostty configuration
    if [ -f ~/.dotfiles/ghostty/config ]; then
        backup_file ~/.config/ghostty/config
        ln -sf ~/.dotfiles/ghostty/config ~/.config/ghostty/config
        print_success "Linked Ghostty configuration"
    else
        print_warning "Ghostty config not found in dotfiles"
    fi

    # Hammerspoon configuration
    if [ -f ~/.dotfiles/hammerspoon/init.lua ]; then
        mkdir -p ~/.hammerspoon
        backup_file ~/.hammerspoon/init.lua
        ln -sf ~/.dotfiles/hammerspoon/init.lua ~/.hammerspoon/init.lua
        print_success "Linked Hammerspoon configuration"
    else
        print_warning "Hammerspoon config not found in dotfiles"
    fi

    # Break timer configuration (Ghostty shader + Hammerspoon)
    if [ -f ~/.dotfiles/break-timer/config.lua ]; then
        mkdir -p ~/.config/break-timer
        backup_file ~/.config/break-timer/config.lua
        ln -sf ~/.dotfiles/break-timer/config.lua ~/.config/break-timer/config.lua
        print_success "Linked break-timer configuration"
    else
        print_warning "break-timer config not found in dotfiles"
    fi
}

# Link VS Code configuration and install the curated extension set.
link_vscode() {
    print_info "🧭 Setting up VS Code..."

    if is_macos; then
        local vscode_user_dir="$HOME/Library/Application Support/Code/User"
    else
        local vscode_user_dir="$HOME/.config/Code/User"
    fi

    mkdir -p "$vscode_user_dir"

    local source_file
    local target_file
    for file_name in settings.json keybindings.json; do
        source_file="$HOME/.dotfiles/vscode/$file_name"
        target_file="$vscode_user_dir/$file_name"

        if [ ! -f "$source_file" ]; then
            print_warning "VS Code $file_name not found in dotfiles"
            continue
        fi

        if [ -L "$target_file" ] && [ "$(readlink "$target_file")" = "$source_file" ]; then
            print_success "VS Code $file_name already linked"
            continue
        fi

        backup_file "$target_file"
        ln -sf "$source_file" "$target_file"
        print_success "Linked VS Code $file_name"
    done

    if ! command -v code >/dev/null 2>&1; then
        print_warning "VS Code CLI not found; skipping extension installation"
        return
    fi

    local extensions_file="$HOME/.dotfiles/vscode/extensions.txt"
    if [ ! -f "$extensions_file" ]; then
        print_warning "VS Code extensions.txt not found"
        return
    fi

    local installed_extensions
    installed_extensions="$(code --list-extensions 2>/dev/null)"

    while IFS= read -r extension_id || [ -n "$extension_id" ]; do
        case "$extension_id" in
            ""|\#*) continue ;;
        esac

        if printf '%s\n' "$installed_extensions" | grep -Fxq "$extension_id"; then
            print_success "VS Code extension already installed: $extension_id"
        elif code --install-extension "$extension_id" >/dev/null 2>&1; then
            print_success "Installed VS Code extension: $extension_id"
        else
            print_warning "Failed to install VS Code extension: $extension_id"
        fi
    done < "$extensions_file"
}

# Install Neovim plugins
install_neovim_plugins() {
    print_info "📦 Installing Neovim plugins..."

    # Check if Neovim is installed
    if ! command -v nvim >/dev/null 2>&1; then
        print_warning "Neovim not found. Please run ./install.sh first"
        return
    fi

    # Initialize Lazy.nvim and install plugins
    print_info "Initializing Lazy.nvim and installing plugins..."
    print_info "This may take a few minutes on first run..."

    # Run Neovim headless to bootstrap Lazy.nvim and install plugins
    if nvim --headless -c "qall" 2>/dev/null; then
        print_success "Lazy.nvim bootstrapped successfully"
        print_info "Plugins will be installed on first Neovim launch"
        print_info "Or run: nvim --headless \"+Lazy! sync\" +qa"
    else
        print_warning "Please launch Neovim manually to complete plugin installation"
    fi
}

# Check for required software
check_requirements() {
    print_info "🔍 Checking for required software..."

    local missing_tools=()
    local tools=("tmux" "git")

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_warning "Missing required tools: ${missing_tools[*]}"
        print_info "Please run ./install.sh first to install required software (supports macOS/Ubuntu)"
        return 1
    fi

    print_success "All required tools are installed"
    return 0
}

# Setup Claude Code & Codex CLI status lines
link_ai_clis() {
    print_info "🤖 Linking AI CLI configs..."

    # Claude Code statusLine script — dotfiles is the single source of truth.
    if [ -d ~/.claude ]; then
        backup_file ~/.claude/statusline-command.sh
        ln -sf ~/.dotfiles/claude/statusline-command.sh ~/.claude/statusline-command.sh
        print_success "Linked ~/.claude/statusline-command.sh"
        print_warning "settings.json must set statusLine.command = bash ~/.claude/statusline-command.sh"
    fi

    # Codex CLI: config.toml is machine-managed, so we don't symlink it.
    # Merge codex/statusline.toml's [tui] block by hand, or run /statusline in Codex.
    print_warning "Codex: merge ~/.dotfiles/codex/statusline.toml [tui] block into ~/.codex/config.toml (or use /statusline)"
}

# Main setup flow
main() {
    print_info "Starting dotfiles configuration setup..."
    echo ""

    # Check if required software is installed
    if ! check_requirements; then
        echo ""
        print_error "Please install required software first by running: ./install.sh (supports macOS and Ubuntu)"
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

    link_vscode
    echo ""

    link_ai_clis
    echo ""

    install_neovim_plugins
    echo ""

    print_success "✅ Dotfiles configuration setup complete!"
    echo ""
    print_info "📝 Next steps:"
    echo "1. Restart your terminal or run: source ~/.zshrc"
    echo "2. Open VS Code and verify Ctrl+h/j/k/l and Ctrl+u/i"
    echo "3. Open tmux and press: Prefix + I (to install tmux plugins)"
    echo "4. Import chrome/vimium-c.json from Vimium C Options"

    if is_macos; then
        echo ""
        print_info "🍎 Starting macOS services..."
        # skhd
        if command -v skhd >/dev/null 2>&1; then
            skhd --start-service 2>/dev/null
            print_success "skhd service started (auto-starts on login)"
        else
            print_warning "skhd not found. Install with: brew install koekeishiya/formulae/skhd"
        fi
    fi

    echo ""
    print_info "💡 Tips:"
    echo "- Previous configs are backed up with timestamp"
    echo "- Run 'gcmc' for AI-powered git commits"
    echo "- Neovim and Kitty are kept as legacy configurations"
}

# Run main function
main "$@"
