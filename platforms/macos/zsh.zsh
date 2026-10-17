# macOS application integration.
export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"

# Legacy Ghostty wallpaper helper is macOS-only.
if [[ "$TERM_PROGRAM" == "ghostty" ]]; then
  ~/.dotfiles/ghostty/random-wallpaper.sh >/dev/null 2>&1
fi

# Keep desktop presets separate from the shell prompt's `theme` variable.
desktop-theme() {
  "$HOME/.dotfiles/scripts/desktop-theme.sh" "$@"
}

# iOS Simulator
alias sim='open -a Simulator'
alias sim-iphone='xcrun simctl boot "iPhone 16" && open -a Simulator'
alias sim-ipad='xcrun simctl boot "iPad Pro 13-inch (M4)" && open -a Simulator'
alias sim-list='xcrun simctl list devices available'
alias sim-shutdown='xcrun simctl shutdown all'

_ubuntu_desktop() {
  local rdp_password
  rdp_password="$(security find-generic-password -a 'iv@home' -s 'GNOME RDP home' -w)" || return 1

  print -r -- "$rdp_password" | /opt/homebrew/bin/sdl-freerdp \
    /v:iv-G5-5090.tail4b3505.ts.net \
    /u:iv \
    /from-stdin:force \
    /cert:tofu \
    /network:auto \
    /size:1600x900 \
    +smart-sizing \
    +clipboard
  local rdp_status=$pipestatus[2]

  unset rdp_password
  return "$rdp_status"
}
alias ubuntu-desktop='_ubuntu_desktop'
alias urdp='_ubuntu_desktop'


# System diagnosis
alias freeze='~/.dotfiles/scripts/freeze-diagnosis.sh'
alias freeze-monitor='~/.dotfiles/scripts/freeze-diagnosis.sh --monitor'
alias freeze-review='~/.dotfiles/scripts/freeze-diagnosis.sh --review'
