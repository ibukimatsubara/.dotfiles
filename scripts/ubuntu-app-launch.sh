#!/usr/bin/env bash
# Share native Hyprland startup between hotkeys and desktop launchers.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
app="${1:?Specify ghostty, chrome, zen, or vscode}"
shift
case "$app" in
    ghostty) binary=ghostty ;;
    chrome) binary=google-chrome ;;
    zen) binary=zen ;;
    vscode) binary=code ;;
    *) printf 'Unknown desktop app: %s\n' "$app" >&2; exit 64 ;;
esac
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [[ ":${XDG_CURRENT_DESKTOP:-}:" == *:Hyprland:* ]]; then
    export GDK_BACKEND=wayland
    unset DISPLAY XAUTHORITY
    case "$app" in
        # Isolate new windows from the long-running GTK renderer state.
        ghostty) exec "$binary" --gtk-single-instance=false "${@/--gtk-single-instance=true/--gtk-single-instance=false}" ;;
        # GDK_BACKEND above already selects Wayland for Firefox-based browsers.
        zen) exec "$binary" "$@" ;;
        *) exec "$binary" --ozone-platform=wayland "$@" ;;
    esac
fi
exec "$binary" "$@"
