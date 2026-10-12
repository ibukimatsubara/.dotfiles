#!/bin/sh

free_percentage="$(memory_pressure -Q 2>/dev/null | awk '/System-wide memory free percentage/ { gsub(/%/, "", $5); print $5 }')"

if [ -z "$free_percentage" ]; then
    exit 0
fi

used_percentage=$((100 - free_percentage))
sketchybar --set "$NAME" label="${used_percentage}%"
