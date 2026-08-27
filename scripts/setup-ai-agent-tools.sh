#!/bin/bash

# Reinstall the non-secret, user-scoped AI tooling used by the personal agent
# configuration. OAuth connections and account-specific permissions remain
# manual by design.

print_info() {
    echo -e "\033[34m$1\033[0m"
}

print_success() {
    echo -e "\033[32m✓ $1\033[0m"
}

print_warning() {
    echo -e "\033[33m⚠ $1\033[0m"
}

install_codex_plugins() {
    if ! command -v codex >/dev/null 2>&1; then
        print_warning "Codex CLI not found; skipping Codex plugins"
        return
    fi

    print_info "Installing Codex personal plugins..."

    local plugin_ref
    for plugin_ref in \
        github@openai-curated \
        build-web-apps@openai-curated \
        build-ios-apps@openai-curated \
        test-android-apps@openai-curated \
        gmail@openai-curated \
        google-calendar@openai-curated; do
        if codex plugin list 2>/dev/null | grep -F "$plugin_ref" | grep -q "installed, enabled"; then
            print_success "$plugin_ref already installed"
        elif codex plugin add "$plugin_ref" >/dev/null 2>&1; then
            print_success "$plugin_ref installed"
        else
            print_warning "Failed to install $plugin_ref"
        fi
    done
}

ensure_claude_marketplace() {
    local marketplace_name="$1"
    local marketplace_source="$2"

    if claude plugin marketplace list 2>/dev/null | grep -Fq "$marketplace_name"; then
        print_success "$marketplace_name marketplace already configured"
    elif claude plugin marketplace add "$marketplace_source" >/dev/null 2>&1; then
        print_success "$marketplace_name marketplace configured"
    else
        print_warning "Failed to configure $marketplace_name marketplace"
    fi
}

install_claude_plugins() {
    if ! command -v claude >/dev/null 2>&1; then
        print_warning "Claude Code CLI not found; skipping Claude plugins"
        return
    fi

    print_info "Installing Claude Code personal plugins..."

    ensure_claude_marketplace "openai-codex" "openai/codex-plugin-cc"
    ensure_claude_marketplace "anthropic-agent-skills" "anthropics/skills"

    local plugin_ref
    for plugin_ref in \
        codex@openai-codex \
        frontend-design@claude-plugins-official \
        swift-lsp@claude-plugins-official \
        pr-review-toolkit@claude-plugins-official \
        claude-code-setup@claude-plugins-official \
        commit-commands@claude-plugins-official \
        typescript-lsp@claude-plugins-official \
        pyright-lsp@claude-plugins-official \
        document-skills@anthropic-agent-skills; do
        if claude plugin list 2>/dev/null | grep -Fq "$plugin_ref"; then
            print_success "$plugin_ref already installed"
        elif claude plugin install "$plugin_ref" --scope user >/dev/null 2>&1; then
            print_success "$plugin_ref installed"
        else
            print_warning "Failed to install $plugin_ref"
        fi
    done
}

install_language_servers() {
    if ! command -v npm >/dev/null 2>&1; then
        print_warning "npm not found; skipping TypeScript and Pyright language servers"
        return
    fi

    if command -v typescript-language-server >/dev/null 2>&1 && \
       command -v pyright-langserver >/dev/null 2>&1; then
        print_success "TypeScript and Pyright language servers already installed"
        return
    fi

    print_info "Installing TypeScript and Pyright language servers..."
    if npm install --global typescript typescript-language-server pyright >/dev/null 2>&1; then
        print_success "TypeScript and Pyright language servers installed"
    else
        print_warning "Failed to install TypeScript or Pyright language servers"
    fi
}

main() {
    install_codex_plugins
    install_claude_plugins
    install_language_servers
    print_info "OAuth connections and plugin permissions must be configured interactively."
}

main "$@"
