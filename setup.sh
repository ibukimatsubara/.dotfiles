#!/usr/bin/env bash
# Public entry point: common behavior plus the detected OS profile.
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES_ROOT/platforms/common/lib.sh"

main() {
    DOTFILES_PLATFORM="$(detect_platform)" || return 1
    source "$DOTFILES_ROOT/platforms/common/setup.sh"
    source "$DOTFILES_ROOT/platforms/$DOTFILES_PLATFORM/setup.sh"
    print_info "Using common + $DOTFILES_PLATFORM profile"
    check_requirements || return 1
    setup_common || return 1
    setup_platform || return 1
    print_success "Dotfiles configured. Restart your shell; reload Ghostty and tmux."
    print_info "VS Code settings are composed at setup time; rerun ./setup.sh after editing them."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
