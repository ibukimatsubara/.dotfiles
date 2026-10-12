#!/bin/sh

action="${1:-on}"
year="$(date '+%Y')"
month="$(date '+%m')"
day="$(date '+%d' | sed 's/^0//')"
weekday="$(LC_ALL=C date '+%A' | tr '[:lower:]' '[:upper:]')"
calendar_output="$(LC_ALL=C /usr/bin/cal "$month" "$year")"

month_label="$(printf '%s\n' "$calendar_output" | sed -n '1p' | sed 's/^ *//; s/ *$//')"
weekdays="$(printf '%s\n' "$calendar_output" | sed -n '2p' | sed 's/ *$//')"

sketchybar --set calendar.today icon="$day" label="$weekday" \
           --set calendar.month label="$month_label" \
           --set calendar.weekdays label="$weekdays"

week_number=1
while [ "$week_number" -le 6 ]; do
    line_number=$((week_number + 2))
    week_line="$(printf '%s\n' "$calendar_output" | sed -n "${line_number}p" | sed 's/ *$//')"
    week_item="calendar.week.$week_number"

    if [ -n "$(printf '%s' "$week_line" | tr -d ' ')" ]; then
        sketchybar --set "$week_item" drawing=on label="$week_line"
    else
        sketchybar --set "$week_item" drawing=off
    fi

    week_number=$((week_number + 1))
done

sketchybar --set date popup.drawing="$action"
