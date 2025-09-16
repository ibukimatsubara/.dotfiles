#!/bin/bash

# Get the focused application
APP=$(yabai -m query --windows --window | jq -r '.app')

# App icon mapping (using SketchyBar icon font)
get_app_icon() {
    case "$1" in
        "kitty"|"Terminal"|"iTerm2") echo "󰆍" ;;  # Terminal icon
        "Code"|"Visual Studio Code") echo "󰨞" ;;  # Code icon
        "Safari") echo "󰀹" ;;                      # Safari icon
        "Chrome"|"Google Chrome") echo "󰊯" ;;     # Chrome icon
        "Firefox") echo "󰈹" ;;                    # Firefox icon
        "Arc") echo "󰇩" ;;                        # Arc browser icon
        "Finder") echo "󰉋" ;;                     # Folder icon
        "Mail") echo "󰇮" ;;                       # Mail icon
        "Messages") echo "󰭻" ;;                   # Messages icon
        "Slack") echo "󰒱" ;;                      # Slack icon
        "Discord") echo "󰙯" ;;                    # Discord icon
        "Spotify") echo "󰓇" ;;                    # Spotify icon
        "Music") echo "󰝚" ;;                      # Music icon
        "System Preferences"|"System Settings") echo "󰒓" ;; # Settings icon
        "Xcode") echo "󰀵" ;;                      # Xcode icon
        "Docker Desktop") echo "󰡨" ;;             # Docker icon
        "Obsidian") echo "󰈙" ;;                   # Document icon
        "Notion") echo "󰈙" ;;                     # Notion icon
        "Figma") echo "󰕘" ;;                      # Figma vector icon
        "Preview") echo "󰈟" ;;                    # Image icon
        "Photoshop"|"GIMP") echo "󰈟" ;;          # Image icon
        "VirtualBuddy") echo "󰍹" ;;               # VM icon
        "Simulator") echo "󰀲" ;;                  # Simulator icon
        *) echo "󰀻" ;;                           # Generic app icon
    esac
}

if [ -n "$APP" ] && [ "$APP" != "null" ]; then
    ICON=$(get_app_icon "$APP")

    # Truncate long app names
    if [ ${#APP} -gt 12 ]; then
        DISPLAY_NAME="${APP:0:12}..."
    else
        DISPLAY_NAME="$APP"
    fi

    sketchybar --set front_app \
        icon="$ICON" \
        label="$DISPLAY_NAME" \
        drawing=on
else
    sketchybar --set front_app drawing=off
fi