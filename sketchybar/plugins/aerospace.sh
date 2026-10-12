#!/bin/sh

workspace_id="$1"
focused_workspace="${FOCUSED_WORKSPACE:-}"

if [ -z "$focused_workspace" ]; then
    focused_workspace="$(aerospace list-workspaces --focused 2>/dev/null)"
fi

# shellcheck source=/dev/null
. "$CONFIG_DIR/colors.sh"

if [ "$workspace_id" = "$focused_workspace" ]; then
    sketchybar --set "$NAME" \
        background.drawing=on \
        label.color="$DARK_COLOR"
else
    sketchybar --set "$NAME" \
        background.drawing=off \
        label.color="$MUTED_COLOR"
fi
