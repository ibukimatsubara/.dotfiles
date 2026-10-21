#!/usr/bin/env bash
# Sourced by the root entry point.

create_directories() {
    print_info "📁 Creating configuration directories..."

    # Neovim directories
    mkdir -p ~/.config/nvim/plugin
    mkdir -p ~/.config/nvim/undo
    mkdir -p ~/.local/share/nvim/undo
    mkdir -p ~/.local/share/nvim/session
    mkdir -p "$HOME/.config/herdr"

    print_success "Directories created"
}

backup_file() {
    if [ -f "$1" ] || [ -L "$1" ]; then
        local backup_name="$1.bak-$(date +%Y%m%d-%H%M%S)"
        print_warning "Backing up existing $1 to $backup_name"
        mv "$1" "$backup_name"
    fi
}

link_managed_path() {
    local source_path="$1"
    local target_path="$2"

    if [ -L "$target_path" ] && [ "$(readlink "$target_path")" = "$source_path" ]; then
        print_success "$target_path already linked"
        return
    fi

    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
        local backup_path="$target_path.bak-$(date +%Y%m%d-%H%M%S)"
        print_warning "Backing up existing $target_path to $backup_path"
        mv "$target_path" "$backup_path"
    fi

    mkdir -p "$(dirname "$target_path")"
    ln -s "$source_path" "$target_path"
    print_success "Linked $target_path"
}

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

link_music_configs() {
    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    local generated_dir="$config_home/dotfiles/mpd/$DOTFILES_PLATFORM"
    local output_config="$DOTFILES_ROOT/platforms/$DOTFILES_PLATFORM/mpd-output.conf"
    [ -r "$output_config" ] || return 1
    mkdir -p "$HOME/Music" "$HOME/.local/share/mpd/playlists" \
        "$HOME/.local/state/mpd" "$generated_dir"
    local temporary
    temporary="$(mktemp "$generated_dir/mpd.conf.XXXXXX")" || return 1
    if ! cat "$DOTFILES_ROOT/mpd/mpd.conf" "$output_config" > "$temporary"; then
        rm -f "$temporary"
        return 1
    fi
    if [ -f "$generated_dir/mpd.conf" ] && cmp -s "$temporary" "$generated_dir/mpd.conf"; then
        rm -f "$temporary"
    else
        mv "$temporary" "$generated_dir/mpd.conf"
    fi
    link_managed_path "$generated_dir/mpd.conf" "$config_home/mpd/mpd.conf"
    link_managed_path "$generated_dir/mpd.conf" "$HOME/.mpdconf"
    link_managed_path "$DOTFILES_ROOT/rmpc/config.ron" "$config_home/rmpc/config.ron"
    link_managed_path "$DOTFILES_ROOT/scripts/music-player.sh" "$HOME/.local/bin/music"
    link_managed_path "$DOTFILES_ROOT/scripts/music-sync.sh" "$HOME/.local/bin/music-sync"
    local player_config="${CLIAMP_CONFIG_DIR:-$config_home/cliamp}"
    local initial_library='~/Music'
    [ "$DOTFILES_PLATFORM" != macos ] || initial_library='~/Music/Shared'
    mkdir -p "$player_config/playlists"
    if [ ! -e "$player_config/playlists/Music.toml" ]; then
        printf '[[dir]]\npath = "%s"\n' "$initial_library" > "$player_config/playlists/Music.toml"
    fi
    if [ ! -e "$player_config/podcast_subscriptions.json" ]; then
        printf '[]\n' > "$player_config/podcast_subscriptions.json"
        chmod 600 "$player_config/podcast_subscriptions.json"
    fi
    if [ "$DOTFILES_PLATFORM" = ubuntu ]; then
        link_managed_path "$DOTFILES_ROOT/platforms/ubuntu/dotfiles-mpd.service" \
            "$config_home/systemd/user/dotfiles-mpd.service"
    fi
}

link_neovim() {
    if [ -L "$HOME/.config/nvim" ] && \
       [ "$(readlink "$HOME/.config/nvim")" = "$HOME/.dotfiles/nvim" ]; then
        print_success "Neovim configuration root already linked"
        return
    fi
    local path
    for path in init.lua lua plugin coc-settings.json; do
        if [ -e "$DOTFILES_ROOT/nvim/$path" ]; then
            link_managed_path "$DOTFILES_ROOT/nvim/$path" "$HOME/.config/nvim/$path"
        fi
    done
}

link_tmux() {
    print_info "🖥️  Linking tmux configuration..."

    if [ -f ~/.dotfiles/tmux/tmux.conf ]; then
        link_managed_path "$DOTFILES_ROOT/tmux/tmux.conf" "$HOME/.tmux.conf"
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

link_herdr() {
    print_info "🐑 Linking Herdr configuration..."

    if [ -f "$HOME/.dotfiles/herdr/config.toml" ]; then
        link_managed_path \
            "$HOME/.dotfiles/herdr/config.toml" \
            "$HOME/.config/herdr/config.toml"
    else
        print_warning "Herdr config not found in dotfiles"
    fi
}

link_ghostty() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
    local source_path
    source_path="$(ghostty_config_source)"
    if [ ! -f "$source_path" ]; then
        print_warning "Ghostty config not found in dotfiles"
        return
    fi
    link_managed_path "$source_path" "$config_dir/config"
    link_managed_path "$HOME/.dotfiles/ghostty/shaders" "$config_dir/shaders"
}

link_vscode() {
    print_info "🧭 Setting up VS Code..."

    local vscode_user_dir
    vscode_user_dir="$(vscode_config_dir)"
    if ! command -v jq >/dev/null 2>&1; then
        print_error "jq is required to compose VS Code settings; run ./install.sh first"
        return 1
    fi

    local generated_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/vscode/$DOTFILES_PLATFORM"
    mkdir -p "$generated_dir" "$vscode_user_dir"
    local temp_settings
    temp_settings="$(mktemp "$generated_dir/settings.json.XXXXXX")" || return 1
    if ! jq -s '.[0] * .[1]' \
        "$DOTFILES_ROOT/vscode/settings.json" \
        "$DOTFILES_ROOT/platforms/$DOTFILES_PLATFORM/vscode-settings.json" > "$temp_settings"; then
        rm -f "$temp_settings"
        return 1
    fi
    if [ -f "$generated_dir/settings.json" ] && cmp -s "$temp_settings" "$generated_dir/settings.json"; then
        rm -f "$temp_settings"
    else
        mv "$temp_settings" "$generated_dir/settings.json"
    fi
    link_managed_path "$generated_dir/settings.json" "$vscode_user_dir/settings.json"
    link_managed_path "$DOTFILES_ROOT/vscode/keybindings.json" "$vscode_user_dir/keybindings.json"

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

check_requirements() {
    print_info "🔍 Checking for required software..."

    local missing_tools=()
    local tools=("tmux" "git" "jq")

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

setup_common() {
    create_directories
    setup_zsh
    link_neovim
    link_tmux
    link_herdr
    link_ghostty
    link_music_configs || return 1
    link_vscode || return 1
    install_neovim_plugins
}
