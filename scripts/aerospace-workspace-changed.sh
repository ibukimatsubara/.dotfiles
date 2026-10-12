#!/bin/sh

# Keep the visible workspace indicator synchronous and move slower Aqua Voice
# reconciliation into one coalescing background worker.

runtime_dir="${TMPDIR:-/tmp}/dotfiles-aerospace-workspace-$(id -u)"
worker_lock="$runtime_dir/aqua-reconcile.lock"
worker_pending="$runtime_dir/aqua-reconcile.pending"

mkdir -p "$runtime_dir"

apply_workspace_highlight() {
    target_workspace="$1"

    case "$target_workspace" in
        1|2|3|4|5|6|7|8|9) ;;
        *) return ;;
    esac

    colors_file="${CONFIG_DIR:-$HOME/.config/sketchybar}/colors.sh"
    if [ -r "$colors_file" ]; then
        # shellcheck source=/dev/null
        . "$colors_file"
    else
        DARK_COLOR=0xff1b1410
        MUTED_COLOR=0xffb9a696
        TEXT_COLOR=0xfff2e7dc
    fi

    sketchybar \
        --set '/workspace\..*/' \
            background.drawing=off \
            icon.color="$MUTED_COLOR" \
            label.color="$TEXT_COLOR" \
        --set "workspace.$target_workspace" \
            background.drawing=on \
            icon.color="$DARK_COLOR" \
            label.color="$DARK_COLOR"
}

run_aqua_reconciler() {
    lock_held=true

    cleanup_lock() {
        if [ "$lock_held" = true ]; then
            rmdir "$worker_lock" 2>/dev/null || true
        fi
    }
    trap cleanup_lock EXIT HUP INT TERM

    while :; do
        rm -f "$worker_pending"

        focused_workspace="$(aerospace list-workspaces --focused 2>/dev/null)"
        if [ -n "$focused_workspace" ]; then
            aerospace list-windows --all \
                --format '%{window-id}|%{workspace}|%{app-bundle-id}' 2>/dev/null |
                while IFS='|' read -r window_id workspace_id app_bundle_id; do
                    if [ "$app_bundle_id" = "com.electron.aqua-voice" ] && \
                       [ "$workspace_id" != "$focused_workspace" ]; then
                        aerospace move-node-to-workspace "$focused_workspace" \
                            --window-id "$window_id" >/dev/null 2>&1 || true
                    fi
                done
        fi

        latest_workspace="$(aerospace list-workspaces --focused 2>/dev/null)"
        if command -v sketchybar >/dev/null 2>&1 && [ -n "$latest_workspace" ]; then
            apply_workspace_highlight "$latest_workspace"
        fi

        if [ -e "$worker_pending" ] || \
           { [ -n "$latest_workspace" ] && [ "$latest_workspace" != "$focused_workspace" ]; }; then
            continue
        fi

        # Release the lock, then recheck the pending signal. This handshake
        # closes the race where a workspace change lands as the worker exits.
        rmdir "$worker_lock" 2>/dev/null || true
        lock_held=false

        if [ -e "$worker_pending" ] && mkdir "$worker_lock" 2>/dev/null; then
            lock_held=true
            continue
        fi

        break
    done
}

if [ "${1:-}" = "--worker" ]; then
    if command -v aerospace >/dev/null 2>&1; then
        run_aqua_reconciler
    else
        rmdir "$worker_lock" 2>/dev/null || true
    fi
    exit 0
fi

requested_workspace="${1:-${AEROSPACE_FOCUSED_WORKSPACE:-}}"
[ -z "$requested_workspace" ] && exit 0

# This is the only synchronous path: one SketchyBar transaction, normally
# around 10 ms. Everything involving AeroSpace window inspection runs below.
if command -v sketchybar >/dev/null 2>&1; then
    apply_workspace_highlight "$requested_workspace"
fi

: > "$worker_pending"
if command -v aerospace >/dev/null 2>&1 && mkdir "$worker_lock" 2>/dev/null; then
    "$0" --worker </dev/null >/dev/null 2>&1 &
fi
