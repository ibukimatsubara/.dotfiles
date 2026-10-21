#!/bin/sh
# Shared meter helpers for AI usage items; source after colors.sh.

circle_icon() {
    percentage="$1"

    if [ "$percentage" -le 0 ]; then
        printf '○'
    elif [ "$percentage" -le 12 ]; then
        printf '󰪞'
    elif [ "$percentage" -le 25 ]; then
        printf '󰪟'
    elif [ "$percentage" -le 37 ]; then
        printf '󰪠'
    elif [ "$percentage" -le 50 ]; then
        printf '󰪡'
    elif [ "$percentage" -le 62 ]; then
        printf '󰪢'
    elif [ "$percentage" -le 75 ]; then
        printf '󰪣'
    elif [ "$percentage" -le 87 ]; then
        printf '󰪤'
    else
        printf '󰪥'
    fi
}

meter_color() {
    percentage="$1"

    if [ "$percentage" -le 25 ]; then
        printf '%s' "$RED_COLOR"
    elif [ "$percentage" -le 50 ]; then
        printf '%s' "$YELLOW_COLOR"
    else
        printf '%s' "$GREEN_COLOR"
    fi
}
