#!/usr/bin/env bash
# Sourced by the root entry point.

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

detect_platform() {
    case "$(uname -s)" in
        Darwin) printf 'macos\n' ;;
        Linux)
            local release_file="${1:-/etc/os-release}"
            local ID='' ID_LIKE=''
            if [ -r "$release_file" ]; then
                . "$release_file"
            fi
            case " $ID $ID_LIKE " in
                *' ubuntu '*|*' debian '*) printf 'ubuntu\n' ;;
                *) print_error "Unsupported Linux distribution: ${ID:-unknown} (Ubuntu/Debian required)" >&2; return 1 ;;
            esac
            ;;
        *) print_error "Unsupported OS: $(uname -s)" >&2; return 1 ;;
    esac
}
