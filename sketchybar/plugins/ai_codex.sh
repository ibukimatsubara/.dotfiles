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

CODEX_P=$(jq -r '.[] | select(.provider == "codex") | .usage.primary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)
CODEX_S=$(jq -r '.[] | select(.provider == "codex") | .usage.secondary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)

if [ -n "$CODEX_P" ]; then
    REM_P=$((100 - CODEX_P))
    REM_S=$((100 - CODEX_S))
    BAR_P=$(make_bar $REM_P)
    BAR_S=$(make_bar $REM_S)
    sketchybar --set $NAME label="Codex ${REM_P}% ${BAR_P} ${REM_S}% ${BAR_S}"
else
    sketchybar --set $NAME label=""
fi
