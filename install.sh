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
        local essentials=("tmux:tmux" "git:git" "jq:jq" "fzf:fzf" "zoxide:zoxide" "direnv:direnv" "ripgrep:rg" "gh:gh" "fnm:fnm")
    else
        local essentials=("tmux:tmux" "git:git" "jq:jq" "fzf:fzf" "zoxide:zoxide" "direnv:direnv" "ripgrep:rg" "gh:gh" "xclip:xclip" "curl:curl")
    fi

    local spec
    local package_name
    local command_name
    for spec in "${essentials[@]}"; do
        package_name="${spec%%:*}"
        command_name="${spec#*:}"

        if ! command -v "$command_name" >/dev/null 2>&1; then
            print_info "Installing $package_name..."
            if pkg_install "$package_name"; then
                print_success "$package_name installed"
            else
                print_warning "Failed to install $package_name"
            fi
        else
            print_success "$package_name already installed"
        fi
    done
}

# Install the desktop applications used in the primary development workflow.
install_desktop_apps() {
    if ! is_macos; then
        print_info "🖥️ Desktop apps on Ubuntu..."
        print_info "Install VS Code, Chrome, and Ghostty from their official distributions"
        return
    fi

    print_info "🖥️ Installing desktop development apps..."

    local desktop_casks=(
        "ghostty"
        "visual-studio-code"
        "google-chrome"
        "hammerspoon"
        "codex"
    )

    for cask in "${desktop_casks[@]}"; do
        if brew list --cask "$cask" >/dev/null 2>&1; then
            print_success "$cask already installed"
        elif brew install --cask "$cask" >/dev/null 2>&1; then
            print_success "$cask installed"
        else
            print_warning "Failed to install $cask; it may already exist outside Homebrew"
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

# Install macOS hotkey tools
install_macos_tools() {
    if ! is_macos; then
        print_info "Skipping macOS-specific tools (not on macOS)"
        return
    fi

    print_info "⌨️ Installing macOS hotkey tools..."

    local macos_tools=("skhd")

    for tool in "${macos_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            print_info "Installing $tool..."
            brew install "$tool" >/dev/null 2>&1
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

    install_desktop_apps
    echo ""

    install_fonts
    echo ""

    install_macos_tools
    echo ""

    install_optional_tools
    echo ""

    print_success "✅ Software installation complete!"
    echo ""
    print_info "📝 Next steps:"
    echo "1. Run ./setup.sh to configure dotfiles"
    echo "2. Restart your terminal or run: source ~/.zshrc"

    if is_macos; then
        echo "3. For macOS: Enable skhd as needed"
        echo ""
        print_info "💡 macOS Services (optional):"
        echo "- brew services start skhd"
    fi
}

# Run main function
main "$@"
