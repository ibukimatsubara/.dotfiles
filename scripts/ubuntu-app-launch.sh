#!/usr/bin/env bash
# Share native Hyprland startup between hotkeys and desktop launchers.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
app="${1:?Specify ghostty, chrome, or vscode}"
shift
case "$app" in
    ghostty) binary=ghostty ;;
    chrome) binary=google-chrome ;;
    vscode) binary=code ;;
    *) printf 'Unknown desktop app: %s\n' "$app" >&2; exit 64 ;;
esac
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [[ ":${XDG_CURRENT_DESKTOP:-}:" == *:Hyprland:* ]]; then
    export GDK_BACKEND=wayland
    unset DISPLAY XAUTHORITY
    case "$app" in
        # Reuse the GTK application while opening a new terminal window each time.
        ghostty) exec "$binary" --gtk-single-instance=true "${@/--gtk-single-instance=false/--gtk-single-instance=true}" ;;
        *) exec "$binary" --ozone-platform=wayland "$@" ;;
    esac
fi
exec "$binary" "$@"
