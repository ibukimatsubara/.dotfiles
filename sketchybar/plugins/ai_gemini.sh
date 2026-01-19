#!/bin/bash

CACHE_FILE="$HOME/.cache/ai-usage.json"

make_bar() {
    local remaining=$1
    local filled=$(( (remaining + 10) / 20 ))
    local empty=$((5 - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="▰"; done
    for ((i=0; i<empty; i++)); do bar+="▱"; done
    echo "$bar"
}

if [ ! -f "$CACHE_FILE" ]; then
    sketchybar --set $NAME label=""
    exit 0
fi

GEMINI_P=$(jq -r '.[] | select(.provider == "gemini") | .usage.primary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)

if [ -n "$GEMINI_P" ]; then
    REM=$((100 - GEMINI_P))
    BAR=$(make_bar $REM)
    sketchybar --set $NAME label="Gemini ${REM}% ${BAR}"
else
    sketchybar --set $NAME label=""
fi
