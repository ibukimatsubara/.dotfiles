#!/bin/bash

# Get notification badges for LINE, Slack, Discord
get_notification_count() {
    local app_name="$1"
    local count

    case "$app_name" in
        "LINE")
            count=$(osascript -e "
                tell application \"System Events\"
                    try
                        get value of attribute \"AXTitle\" of UI element \"LINE\" of list 1 of application process \"Dock\"
                    on error
                        return \"0\"
                    end try
                end tell
            " 2>/dev/null)
            ;;
        "Slack")
            badge=$(osascript -e "
                tell application \"System Events\"
                    try
                        get value of attribute \"AXTitle\" of UI element \"Slack\" of list 1 of application process \"Dock\"
                    on error
                        return \"0\"
                    end try
                end tell
            " 2>/dev/null)
            # If badge returns app name, there are no notifications
            if [[ "$badge" == "Slack" ]]; then
                count="0"
            else
                count="$badge"
            fi
            ;;
        "Discord")
            count=$(osascript -e "
                tell application \"System Events\"
                    try
                        get value of attribute \"AXTitle\" of UI element \"Discord\" of list 1 of application process \"Dock\"
                    on error
                        return \"0\"
                    end try
                end tell
            " 2>/dev/null)
            ;;
    esac

    # Return 0 if count is empty or non-numeric
    if [[ "$count" =~ ^[0-9]+$ ]]; then
        echo "$count"
    else
        echo "0"
    fi
}

# Get counts for all apps
LINE_COUNT=$(get_notification_count "LINE")
SLACK_COUNT=$(get_notification_count "Slack")
DISCORD_COUNT=$(get_notification_count "Discord")

# Calculate total
TOTAL=$((LINE_COUNT + SLACK_COUNT + DISCORD_COUNT))

# Update SketchyBar
if [ "$TOTAL" -eq 0 ]; then
    # No notifications - hide the item
    sketchybar --set notifications drawing=off
else
    # Show count with bell icon
    DISPLAY="󰂞 $TOTAL"  # Bell with count
    ICON_COLOR="0xffff9580"

    sketchybar --set notifications \
        drawing=on \
        icon="$DISPLAY" \
        icon.color="$ICON_COLOR"
fi