#!/usr/bin/env bash
# Supervise only processes started by this Hyprland instance.
set -uo pipefail
: "${HYPRLAND_INSTANCE_SIGNATURE:?Start this helper from Hyprland}"
export PATH="$HOME/.local/bin:$HOME/.local/share/fnm:$PATH"
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
# Override GNOME's inherited input-method variables for this session.
export GTK_IM_MODULE=
export QT_IM_MODULE=fcitx
export QT_IM_MODULES='wayland;fcitx;ibus'
export XMODIFIERS=@im=fcitx
exec 9>"${XDG_RUNTIME_DIR:?}/dotfiles-hyprland-${HYPRLAND_INSTANCE_SIGNATURE}.lock"
flock -n 9 || exit 0
children=()
desktop_shell_unit="dotfiles-desktop-shell@${HYPRLAND_INSTANCE_SIGNATURE}.service"
cleanup() {
    trap - EXIT
    for child in "${children[@]}"; do
        kill -- "-$child" 2>/dev/null || true
        # The child may still be entering setsid when shutdown begins.
        kill -- "$child" 2>/dev/null || true
    done
    # A stalled GUI client can ignore TERM. Bound shutdown before releasing
    # the session lock so a retry or the next login can start cleanly.
    for attempt in {1..30}; do
        local alive=false
        for child in "${children[@]}"; do
            if kill -0 -- "-$child" 2>/dev/null || kill -0 -- "$child" 2>/dev/null; then alive=true; break; fi
        done
        if ! "$alive"; then break; fi
        sleep 0.1
    done
    for child in "${children[@]}"; do
        kill -KILL -- "-$child" 2>/dev/null || true
        kill -KILL -- "$child" 2>/dev/null || true
    done
    wait 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 0' HUP INT TERM
# DBus-activated apps and portals must receive this session's display.
dbus-update-activation-environment --systemd WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE PATH DISPLAY XAUTHORITY GTK_IM_MODULE QT_IM_MODULE QT_IM_MODULES XMODIFIERS
# Only the supervisor owns the lock; GUI apps may detach their own children.
spawn() { setsid "$@" 9>&- & children+=("$!"); }
scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
desktop_shell="$("$scripts_dir/ubuntu-desktop-shell.sh" current)" || exit 1
systemctl --user start "$desktop_shell_unit" 9>&-
spawn hypridle
spawn fcitx5
spawn python3 "$scripts_dir/ubuntu-break-timer.py" watch
spawn python3 "$scripts_dir/ubuntu-mic-priority.py" --watch
if [ "$desktop_shell" = dms ]; then
    spawn python3 "$scripts_dir/ubuntu-theme.py" watch
fi
if command -v vicinae >/dev/null 2>&1; then
    spawn "$scripts_dir/hyprland-native.sh" vicinae server --config "${XDG_CONFIG_HOME:-$HOME/.config}/vicinae/vicinae.json"
fi
spawn python3 "$scripts_dir/hyprland-workspace-one.py"
while hyprctl -j monitors >/dev/null 2>&1; do
    sleep 3 & wait "$!" || true
done
