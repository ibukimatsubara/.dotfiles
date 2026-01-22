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

# ISO8601からリセットまでの残り時間を計算
time_until() {
    local reset_at=$1
    if [ -z "$reset_at" ] || [ "$reset_at" = "null" ]; then
        echo ""
        return
    fi
    
    local reset_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$reset_at" "+%s" 2>/dev/null)
    if [ -z "$reset_epoch" ]; then
        echo ""
        return
    fi
    
    local now_epoch=$(date +%s)
    local diff=$((reset_epoch - now_epoch))
    
    if [ "$diff" -le 0 ]; then
        echo "0m"
        return
    fi
    
    local days=$((diff / 86400))
    local hours=$(((diff % 86400) / 3600))
    local mins=$(((diff % 3600) / 60))
    
    if [ "$days" -gt 0 ]; then
        echo "${days}d ${hours}h"
    elif [ "$hours" -gt 0 ]; then
        echo "${hours}h ${mins}m"
    else
        echo "${mins}m"
    fi
}

# 色を残り%で決定
get_color() {
    local remaining=$1
    if [ "$remaining" -ge 50 ]; then
        echo "0xff79c0ff"    # 青 (余裕あり)
    elif [ "$remaining" -ge 20 ]; then
        echo "0xffff79c6"    # ピンク (注意)
    else
        echo "0xffff5555"    # 赤 (危険)
    fi
}

if [ ! -f "$CACHE_FILE" ]; then
    sketchybar --set $NAME label=""
    exit 0
fi

ZAI_P=$(jq -r '.[] | select(.provider == "zai") | .usage.primary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)
ZAI_RESET_P=$(jq -r '.[] | select(.provider == "zai") | .usage.primary.resetsAt // empty' "$CACHE_FILE" 2>/dev/null)

if [ -n "$ZAI_P" ]; then
    REM_P=$((100 - ZAI_P))
    BAR_P=$(make_bar $REM_P)
    TIME=$(time_until "$ZAI_RESET_P")
    COLOR=$(get_color $REM_P)
    
    # 名前はアイコンで表示されるので、ラベルには数値のみ
    LABEL="${REM_P}% ${BAR_P}"
    [ -n "$TIME" ] && LABEL+=" ${TIME}"
    
    sketchybar --set $NAME label="$LABEL" label.color=$COLOR
else
    sketchybar --set $NAME label="" icon.drawing=off
fi
