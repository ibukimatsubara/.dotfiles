#!/bin/sh

if ! command -v aerospace >/dev/null 2>&1; then
    exit 0
fi

# shellcheck source=/dev/null
. "${CONFIG_DIR:-$HOME/.config/sketchybar}/colors.sh"

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

workspace_1_label_drawing=off
workspace_2_label_drawing=off
workspace_3_label_drawing=off
workspace_4_label_drawing=off
workspace_5_label_drawing=off
workspace_6_label_drawing=off
workspace_7_label_drawing=off
workspace_8_label_drawing=off
workspace_9_label_drawing=off
workspace_1_icon_padding=7
workspace_2_icon_padding=7
workspace_3_icon_padding=7
workspace_4_icon_padding=7
workspace_5_icon_padding=7
workspace_6_icon_padding=7
workspace_7_icon_padding=7
workspace_8_icon_padding=7
workspace_9_icon_padding=7

[ -n "$workspace_1" ] && workspace_1_label_drawing=on && workspace_1_icon_padding=4
[ -n "$workspace_2" ] && workspace_2_label_drawing=on && workspace_2_icon_padding=4
[ -n "$workspace_3" ] && workspace_3_label_drawing=on && workspace_3_icon_padding=4
[ -n "$workspace_4" ] && workspace_4_label_drawing=on && workspace_4_icon_padding=4
[ -n "$workspace_5" ] && workspace_5_label_drawing=on && workspace_5_icon_padding=4
[ -n "$workspace_6" ] && workspace_6_label_drawing=on && workspace_6_icon_padding=4
[ -n "$workspace_7" ] && workspace_7_label_drawing=on && workspace_7_icon_padding=4
[ -n "$workspace_8" ] && workspace_8_label_drawing=on && workspace_8_icon_padding=4
[ -n "$workspace_9" ] && workspace_9_label_drawing=on && workspace_9_icon_padding=4

# Refresh labels only. Workspace focus is painted by the AeroSpace callback so
# a slower window scan can never overwrite a newer highlight.
sketchybar \
    --set workspace.1 label="$workspace_1" label.drawing="$workspace_1_label_drawing" icon.padding_right="$workspace_1_icon_padding" \
    --set workspace.2 label="$workspace_2" label.drawing="$workspace_2_label_drawing" icon.padding_right="$workspace_2_icon_padding" \
    --set workspace.3 label="$workspace_3" label.drawing="$workspace_3_label_drawing" icon.padding_right="$workspace_3_icon_padding" \
    --set workspace.4 label="$workspace_4" label.drawing="$workspace_4_label_drawing" icon.padding_right="$workspace_4_icon_padding" \
    --set workspace.5 label="$workspace_5" label.drawing="$workspace_5_label_drawing" icon.padding_right="$workspace_5_icon_padding" \
    --set workspace.6 label="$workspace_6" label.drawing="$workspace_6_label_drawing" icon.padding_right="$workspace_6_icon_padding" \
    --set workspace.7 label="$workspace_7" label.drawing="$workspace_7_label_drawing" icon.padding_right="$workspace_7_icon_padding" \
    --set workspace.8 label="$workspace_8" label.drawing="$workspace_8_label_drawing" icon.padding_right="$workspace_8_icon_padding" \
    --set workspace.9 label="$workspace_9" label.drawing="$workspace_9_label_drawing" icon.padding_right="$workspace_9_icon_padding"

# On initial load or a window-change refresh, converge to the actual focus in
# one final transaction. The query-to-paint race window is only a few ms.
focused_workspace="$(aerospace list-workspaces --focused 2>/dev/null)"
case "$focused_workspace" in
    1|2|3|4|5|6|7|8|9)
        sketchybar \
            --set '/workspace\..*/' \
                background.drawing=off \
                icon.color="$MUTED_COLOR" \
                label.color="$TEXT_COLOR" \
            --set "workspace.$focused_workspace" \
                background.drawing=on \
                icon.color="$DARK_COLOR" \
                label.color="$DARK_COLOR"
        ;;
esac
