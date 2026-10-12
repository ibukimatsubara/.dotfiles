#!/bin/sh

if ! command -v aerospace >/dev/null 2>&1; then
    exit 0
fi

# shellcheck source=/dev/null
. "${CONFIG_DIR:-$HOME/.config/sketchybar}/colors.sh"

focused_workspace="${FOCUSED_WORKSPACE:-}"
if [ -z "$focused_workspace" ]; then
    focused_workspace="$(aerospace list-workspaces --focused 2>/dev/null)"
fi

[ -z "$focused_workspace" ] && exit 0

workspace_1=""
workspace_2=""
workspace_3=""
workspace_4=""
workspace_5=""
workspace_6=""
workspace_7=""
workspace_8=""
workspace_9=""

windows="$(aerospace list-windows --all --format '%{workspace}|%{app-name}' 2>/dev/null)"

while IFS='|' read -r workspace_id app_name; do
    [ -z "$workspace_id" ] && continue

    case "$app_name" in
        "Aqua Voice") continue ;;
        Finder) app_icon="󰀶" ;;
        "Google Chrome") app_icon="" ;;
        Safari) app_icon="󰀹" ;;
        Ghostty|ghostty) app_icon="" ;;
        "Visual Studio Code"|Code) app_icon="󰨞" ;;
        Obsidian) app_icon="󱓧" ;;
        Raycast) app_icon="󰱽" ;;
        "Activity Monitor") app_icon="󰄪" ;;
        *) app_icon="󰣆" ;;
    esac

    case "$workspace_id" in
        1) workspace_1="$workspace_1$app_icon " ;;
        2) workspace_2="$workspace_2$app_icon " ;;
        3) workspace_3="$workspace_3$app_icon " ;;
        4) workspace_4="$workspace_4$app_icon " ;;
        5) workspace_5="$workspace_5$app_icon " ;;
        6) workspace_6="$workspace_6$app_icon " ;;
        7) workspace_7="$workspace_7$app_icon " ;;
        8) workspace_8="$workspace_8$app_icon " ;;
        9) workspace_9="$workspace_9$app_icon " ;;
    esac
done <<EOF
$windows
EOF

update_workspace() {
    workspace_id="$1"
    window_icons="$2"

    if [ "$workspace_id" = "$focused_workspace" ]; then
        background_drawing=on
        icon_color="$DARK_COLOR"
        label_color="$DARK_COLOR"
    else
        background_drawing=off
        icon_color="$MUTED_COLOR"
        label_color="$TEXT_COLOR"
    fi

    if [ -n "$window_icons" ]; then
        label_drawing=on
        icon_padding_right=4
    else
        label_drawing=off
        icon_padding_right=7
    fi

    sketchybar --set "workspace.$workspace_id" \
        icon="$workspace_id" \
        icon.color="$icon_color" \
        icon.padding_right="$icon_padding_right" \
        label="$window_icons" \
        label.drawing="$label_drawing" \
        label.color="$label_color" \
        background.drawing="$background_drawing"
}

update_workspace 1 "$workspace_1"
update_workspace 2 "$workspace_2"
update_workspace 3 "$workspace_3"
update_workspace 4 "$workspace_4"
update_workspace 5 "$workspace_5"
update_workspace 6 "$workspace_6"
update_workspace 7 "$workspace_7"
update_workspace 8 "$workspace_8"
update_workspace 9 "$workspace_9"
