#!/bin/bash

echo "📦 Installing required software for dotfiles..."

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

# Check if we're on Linux
is_linux() {
    [[ "$OSTYPE" == "linux"* ]]
}

# Check if package manager is available
check_package_manager() {
    if is_macos; then
        if ! command -v brew >/dev/null 2>&1; then
            print_error "Homebrew is not installed"
            print_info "Install Homebrew from: https://brew.sh"
            print_info "Run: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            return 1
        fi
        print_success "Homebrew is installed ($(brew --version | head -n1))"
    elif is_linux; then
        if ! command -v apt >/dev/null 2>&1; then
            print_error "apt is not available (only Debian/Ubuntu is supported)"
            return 1
        fi
        print_success "apt is available"
        print_info "Updating package lists..."
        sudo apt update >/dev/null 2>&1
    else
        print_error "Unsupported OS: $OSTYPE"
        return 1
    fi
    return 0
}

# Install a package using the system package manager
pkg_install() {
    local pkg="$1"
    if is_macos; then
        brew install "$pkg" >/dev/null 2>&1
    elif is_linux; then
        sudo apt install -y "$pkg" >/dev/null 2>&1
    fi
}

# Install essential tools
install_essentials() {
    print_info "🔧 Installing essential tools..."

    if is_macos; then
        local essentials=("neovim" "tmux" "git" "imagemagick" "luarocks" "jq" "fzf" "zoxide")
    else
        local essentials=("neovim" "tmux" "git" "jq" "fzf" "zoxide" "xclip" "curl")
    fi

    for tool in "${essentials[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            print_info "Installing $tool..."
            pkg_install "$tool"
            print_success "$tool installed"
        else
            print_success "$tool already installed"
        fi
    done
}

# Install fonts
install_fonts() {
    if is_macos; then
        print_info "🔤 Installing Nerd Fonts..."

        local fonts=("font-jetbrains-mono-nerd-font" "font-hack-nerd-font")

        for font in "${fonts[@]}"; do
            if ! brew list --cask | grep -q "$font"; then
                print_info "Installing $font..."
                brew install --cask "$font" >/dev/null 2>&1
                print_success "$font installed"
            else
                print_success "$font already installed"
            fi
        done
    else
        print_info "🔤 Nerd Fonts (Linux)..."
        print_info "Install manually from: https://www.nerdfonts.com/font-downloads"
        print_info "Or run: bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/officialrajdeepsingh/nerd-fonts-installer/main/install.sh)\""
    fi
}

# Install macOS window management tools
install_macos_tools() {
    if ! is_macos; then
        print_info "Skipping macOS-specific tools (not on macOS)"
        return
    fi

    print_info "🪟 Installing macOS window management tools..."

    # Add FelixKratz tap
    print_info "Adding FelixKratz/formulae tap..."
    brew tap FelixKratz/formulae >/dev/null 2>&1

    local macos_tools=("yabai" "skhd" "sketchybar" "borders")

    for tool in "${macos_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            print_info "Installing $tool..."
            if [ "$tool" = "sketchybar" ] || [ "$tool" = "borders" ]; then
                brew install "felixkratz/formulae/$tool" >/dev/null 2>&1
            else
                brew install "$tool" >/dev/null 2>&1
            fi
            print_success "$tool installed"
        else
            print_success "$tool already installed"
        fi
    done
}

# Install optional development tools
install_optional_tools() {
    print_info "🛠️ Installing optional development tools..."

    # Python tools
    if ! command -v uv >/dev/null 2>&1; then
        print_info "Installing uv (Python package manager)..."
        if is_macos; then
            brew install uv >/dev/null 2>&1
        else
            curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
        fi
        print_success "uv installed"
    else
        print_success "uv already installed"
    fi

    # Claude Code CLI
    if ! command -v claude >/dev/null 2>&1; then
        print_warning "Claude Code CLI not found"
        print_info "Install from: https://claude.ai/code"
    else
        print_success "Claude Code CLI already installed"
    fi

    # Terminal file manager
    if ! command -v nnn >/dev/null 2>&1; then
        print_info "Installing nnn (terminal file manager)..."
        pkg_install nnn
        print_success "nnn installed"
    else
        print_success "nnn already installed"
    fi
}

# Install vim-plug for Neovim
install_vim_plug() {
    print_info "📦 Installing vim-plug for Neovim..."

    if [ ! -f "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim" ]; then
        print_info "Downloading vim-plug..."
        sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
         https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim' >/dev/null 2>&1
        print_success "vim-plug installed"
    else
        print_success "vim-plug already installed"
    fi
}

# Main installation flow
main() {
    print_info "Starting software installation..."
    echo ""

    # Check prerequisites
    if ! check_package_manager; then
        exit 1
    fi

    # Update package manager
    if is_macos; then
        print_info "🔄 Updating Homebrew..."
        brew update >/dev/null 2>&1
        print_success "Homebrew updated"
    fi

    # Install software categories
    install_essentials
    echo ""

    install_fonts
    echo ""

    install_macos_tools
    echo ""

    install_optional_tools
    echo ""

    install_vim_plug
    echo ""

    print_success "✅ Software installation complete!"
    echo ""
    print_info "📝 Next steps:"
    echo "1. Run ./setup.sh to configure dotfiles"
    echo "2. Restart your terminal or run: source ~/.zshrc"

    if is_macos; then
        echo "3. For macOS: Enable yabai and skhd services as needed"
        echo ""
        print_info "💡 macOS Services (optional):"
        echo "- brew services start yabai"
        echo "- brew services start skhd"
        echo "- brew services start felixkratz/formulae/sketchybar"
    fi
}

# Run main function
main "$@"