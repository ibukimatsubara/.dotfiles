#!/usr/bin/env bash
# Public entry point: common behavior plus the detected OS profile.
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES_ROOT/platforms/common/lib.sh"

main() {
    DOTFILES_PLATFORM="$(detect_platform)" || return 1
    source "$DOTFILES_ROOT/platforms/common/install.sh"
    source "$DOTFILES_ROOT/platforms/$DOTFILES_PLATFORM/install.sh"
    print_info "Using common + $DOTFILES_PLATFORM profile"
    check_package_manager || return 1
    install_common
    install_platform_tools || return 1
    print_success "Software installation complete. Run ./setup.sh next."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
