#!/bin/bash

# Get space number from item name (space.1 -> 1)
SPACE_ID="${NAME##*.}"

# Get windows in this space and their apps
WINDOWS=$(yabai -m query --windows --space $SPACE_ID)
APPS=$(echo "$WINDOWS" | jq -r '.[].app' | sort -u)
WINDOW_COUNT=$(echo "$WINDOWS" | jq '. | length')

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

# Create label with app icons (max 3 apps shown)
LABEL=""
if [ "$WINDOW_COUNT" -eq 0 ]; then
    # Empty space
    ICON_COLOR="0xff4c566a"
    LABEL=""
else
    # Space has windows
    ICON_COLOR="0xff8b92a9"

    # Show app icons (max 3) with spacing
    APP_ICONS=""
    COUNT=0
    while IFS= read -r app && [ $COUNT -lt 3 ]; do
        if [ -n "$app" ]; then
            APP_ICON=$(get_app_icon "$app")
            if [ $COUNT -eq 0 ]; then
                APP_ICONS="$APP_ICON"
            else
                APP_ICONS="$APP_ICONS  $APP_ICON"  # Add double space between icons
            fi
            COUNT=$((COUNT + 1))
        fi
    done <<< "$APPS"

    # Add count if more than 3 apps
    UNIQUE_APP_COUNT=$(echo "$APPS" | wc -l | tr -d ' ')
    if [ "$UNIQUE_APP_COUNT" -gt 3 ]; then
        APP_ICONS="$APP_ICONS+"
    fi

    LABEL="$APP_ICONS"
fi

# Update space item
if [ "$SELECTED" = "true" ]; then
    sketchybar --set $NAME \
        background.drawing=on \
        icon.highlight=on \
        icon.color=0xffff79c6 \
        label="$LABEL" \
        label.color=0xffff79c6
else
    sketchybar --set $NAME \
        background.drawing=off \
        icon.highlight=off \
        icon.color="$ICON_COLOR" \
        label="$LABEL" \
        label.color="$ICON_COLOR"
fi