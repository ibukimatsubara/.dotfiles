#!/usr/bin/env bash
# Sourced by the root entry point.

install_essentials() {
    print_info "🔧 Installing essential tools..."

    local essentials=("${platform_essentials[@]}")

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

install_optional_tools() {
    print_info "🛠️ Installing optional development tools..."

    # Python tools
    if ! command -v uv >/dev/null 2>&1; then
        print_info "Installing uv (Python package manager)..."
        if install_uv; then
            print_success "uv installed"
        else
            print_warning "Failed to install uv"
        fi
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

    # DeepSeek Harness CLI and the terminal profile used by Cmd+R.
    local dsh_setup_script
    dsh_setup_script="$DOTFILES_ROOT/scripts/setup-dsh.sh"
    if bash "$dsh_setup_script"; then
        print_success "DSH CLI and dsh-tui profile configured"
    else
        print_warning "DSH setup failed; rerun scripts/setup-dsh.sh after fixing its prerequisites"
    fi

    # Pi coding agent CLI
    if command -v pi >/dev/null 2>&1; then
        print_success "Pi coding agent CLI already installed"
    elif ! command -v npm >/dev/null 2>&1; then
        print_warning "npm not found; skipping Pi coding agent CLI installation"
    else
        print_info "Installing Pi coding agent CLI..."
        if npm install -g --ignore-scripts @earendil-works/pi-coding-agent >/dev/null 2>&1; then
            print_success "Pi coding agent CLI installed"
        else
            print_warning "Failed to install Pi coding agent CLI (requires Node.js 22.19 or newer)"
        fi
    fi

    # agent-browser CLI and its managed Chrome runtime
    if command -v agent-browser >/dev/null 2>&1; then
        print_success "agent-browser CLI already installed"
    elif ! command -v npm >/dev/null 2>&1; then
        print_warning "npm not found; skipping agent-browser CLI installation"
    else
        print_info "Installing agent-browser CLI..."
        if npm install -g agent-browser >/dev/null 2>&1; then
            print_success "agent-browser CLI installed"
        else
            print_warning "Failed to install agent-browser CLI"
        fi
    fi

    if command -v agent-browser >/dev/null 2>&1; then
        print_info "Ensuring the agent-browser runtime is installed..."
        if install_browser_runtime; then
            print_success "agent-browser runtime installed"
        else
            print_warning "Failed to install the agent-browser runtime"
        fi
    fi

}

install_common() {
    install_essentials
    install_optional_tools
}
