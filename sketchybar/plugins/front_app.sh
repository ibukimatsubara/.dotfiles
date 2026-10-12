#!/bin/sh

app_name="${INFO:-}"

if [ -z "$app_name" ]; then
    app_name="$(aerospace list-windows --focused --format '%{app-name}' 2>/dev/null)"
fi

if [ -n "$app_name" ]; then
    case "$app_name" in
        Finder) icon="󰀶" ;;
        "Google Chrome") icon="" ;;
        Ghostty|ghostty) icon="" ;;
        "Visual Studio Code"|Code) icon="󰨞" ;;
        Obsidian) icon="󱓧" ;;
        Raycast) icon="󰱽" ;;
        "Activity Monitor") icon="󰄪" ;;
        *) icon="󰣆" ;;
    esac

    sketchybar --set "$NAME" icon="$icon" label="$app_name"
fi
