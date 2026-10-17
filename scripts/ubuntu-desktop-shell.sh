#!/usr/bin/env bash
# Route desktop surfaces through the selected shell; keep DMS as a fallback.
set -euo pipefail
scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
selection="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/desktop-shell"
action="${1:-current}"
if [ "$action" = select ]; then
    backend="${2:?Specify dms or caelestia}"
    case "$backend" in
        dms) command -v dms >/dev/null ;;
        caelestia) command -v caelestia >/dev/null ;;
        *) printf 'Unknown desktop shell: %s\n' "$backend" >&2; exit 64 ;;
    esac
    mkdir -p "$(dirname "$selection")"
    temporary="$(mktemp "${selection}.XXXXXX")"
    printf '%s\n' "$backend" > "$temporary"
    mv -f "$temporary" "$selection"
    printf 'Selected %s. Restart the Hyprland session helper to apply.\n' "$backend"
    exit 0
fi
backend=dms
if [ -f "$selection" ]; then read -r backend < "$selection" || true; fi
case "$backend" in dms|caelestia) ;; *) printf 'Invalid desktop shell: %s\n' "$backend" >&2; exit 64 ;; esac
if [ "$action" = current ]; then printf '%s\n' "$backend"; exit 0; fi
if [ "$backend" = caelestia ]; then
    prefix="$HOME/.local/opt/caelestia"
    export PATH="$prefix/bin:$HOME/.local/bin:$PATH"
    export QML_IMPORT_PATH="$prefix/lib/qt6/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
    export LD_LIBRARY_PATH="$prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export CAELESTIA_LIB_DIR="$prefix/lib/caelestia"
    export QS_ICON_THEME="${QS_ICON_THEME:-Yaru}"
    case "$action" in
        run) exec "$scripts_dir/hyprland-native.sh" qs -c caelestia -n ;;
        launcher|spotlight) exec caelestia shell drawers toggle launcher ;;
        launcher-open) [ "$(caelestia shell drawers isOpen launcher)" = 1 ]; exit $? ;;
        settings) exec caelestia shell nexus open ;;
        notifications) exec caelestia shell drawers toggle sidebar ;;
        wallpaper) exec caelestia shell nexus open ;;
        powermenu) exec caelestia shell drawers toggle session ;;
        *) printf 'Unknown desktop action: %s\n' "$action" >&2; exit 64 ;;
    esac
fi
case "$action" in
    run) exec "$scripts_dir/hyprland-native.sh" dms run ;;
    launcher) exec "$scripts_dir/ubuntu-launcher.sh" ;;
    spotlight) exec dms ipc call spotlight toggle ;;
    settings) exec dms ipc call settings focusOrToggle ;;
    notifications) exec dms ipc call notifications toggle ;;
    wallpaper) exec dms ipc call dankdash wallpaper ;;
    powermenu) exec dms ipc call powermenu toggle ;;
    *) printf 'Unknown desktop action: %s\n' "$action" >&2; exit 64 ;;
esac
