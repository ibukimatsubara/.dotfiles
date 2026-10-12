#!/bin/sh

# AeroSpace emulates workspaces by moving inactive windows off-screen. Aqua
# Voice's recorder is an always-on-top window, so keep it attached to the
# newly focused workspace before refreshing SketchyBar.

requested_workspace="${1:-${AEROSPACE_FOCUSED_WORKSPACE:-}}"

if [ -z "$requested_workspace" ]; then
    exit 0
fi

if command -v aerospace >/dev/null 2>&1; then
    focused_workspace="$requested_workspace"
    attempt=0

    # Rapid workspace changes can overlap callbacks. Re-read the actual focus
    # before and after moving Aqua so the latest workspace always wins.
    while [ "$attempt" -lt 3 ]; do
        current_workspace="$(aerospace list-workspaces --focused 2>/dev/null)"
        [ -n "$current_workspace" ] && focused_workspace="$current_workspace"

        aerospace list-windows --all \
            --format '%{window-id}|%{workspace}|%{app-bundle-id}' 2>/dev/null |
            while IFS='|' read -r window_id workspace_id app_bundle_id; do
                if [ "$app_bundle_id" = "com.electron.aqua-voice" ] && \
                   [ "$workspace_id" != "$focused_workspace" ]; then
                    aerospace move-node-to-workspace "$focused_workspace" \
                        --window-id "$window_id" >/dev/null 2>&1 || true
                fi
            done

        latest_workspace="$(aerospace list-workspaces --focused 2>/dev/null)"
        if [ -z "$latest_workspace" ] || [ "$latest_workspace" = "$focused_workspace" ]; then
            break
        fi

        focused_workspace="$latest_workspace"
        attempt=$((attempt + 1))
    done
else
    focused_workspace="$requested_workspace"
fi

if command -v sketchybar >/dev/null 2>&1; then
    sketchybar --trigger aerospace_workspace_change \
        FOCUSED_WORKSPACE="$focused_workspace"
fi
