#!/bin/bash

set -euo pipefail

print_info() {
    printf '\033[34m%s\033[0m\n' "$1"
}

print_success() {
    printf '\033[32m✓ %s\033[0m\n' "$1"
}

print_error() {
    printf '\033[31m✗ %s\033[0m\n' "$1" >&2
}

main() {
    if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
        print_error "DSH requires Node.js 22.19+ (22.x) or 24+ and npm. Install a current Node.js LTS first."
        return 1
    fi

    if ! node -e '
        const [major, minor] = process.versions.node.split(".").map(Number);
        process.exit(major >= 24 || (major === 22 && minor >= 19) ? 0 : 1);
    '; then
        print_error "Node.js cannot run or its version is unsupported. Install a current Node.js LTS first."
        return 1
    fi

    if ! command -v pnpm >/dev/null 2>&1; then
        print_info "Installing pnpm for DSH profiles..."
        npm install --global pnpm@10
    fi

    local spec tool package_name
    for spec in "dsh:@deepseek-ai/dsh" "dsh-tui:@deepseek-harness-tui/dsh-tui"; do
        tool="${spec%%:*}"
        package_name="${spec#*:}"
        if command -v "$tool" >/dev/null 2>&1 && "$tool" --version >/dev/null 2>&1; then
            print_success "$tool already installed"
        else
            print_info "Installing $package_name..."
            if [ "$tool" = "dsh-tui" ]; then
                # The global TUI is a launcher; the profile resolves its peers.
                npm install --global --legacy-peer-deps "$package_name"
            else
                npm install --global \
                    --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty \
                    "$package_name"
            fi
        fi
    done

    local profile_dir global_root
    profile_dir="${DSH_HOME:-$HOME/.dsh}/profiles/dsh-tui"
    global_root="$(npm root --global)"
    if node - "$profile_dir" "$global_root" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const [profileDir, globalRoot] = process.argv.slice(2);
const name = "@deepseek-harness-tui/dsh-tui";
const readPackage = file => JSON.parse(fs.readFileSync(file, "utf8"));
try {
    const profile = readPackage(path.join(profileDir, "package.json"));
    const installed = readPackage(path.join(profileDir, "node_modules", name, "package.json"));
    const launcher = readPackage(path.join(globalRoot, name, "package.json"));
    fs.accessSync(path.join(profileDir, "node_modules", name, "lib/types/update.js"));
    process.exit(profile.dsh?.profile?.bundles?.includes(name) && installed.version === launcher.version ? 0 : 1);
} catch {
    process.exit(1);
}
NODE
    then
        print_success "dsh-tui profile already configured"
    else
        print_info "Initializing or aligning the dsh-tui profile..."
        dsh-tui update
    fi

    dsh-tui doctor
    print_success "DSH setup complete. Start with: dcode"
    print_info "Sign in inside the TUI with /auth, or configure your API key locally."
}

main "$@"
