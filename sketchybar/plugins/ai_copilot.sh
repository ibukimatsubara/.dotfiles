#!/bin/bash

# マウスホバー時はバー全体を非表示
if [ "$SENDER" = "mouse.entered" ]; then
    source "$CONFIG_DIR/plugins/bar_hover.sh"
    exit 0
fi

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

# 次の月初(1日 00:00 UTC)までの残り時間を計算 (Copilot用)
time_until_next_month() {
    local now_epoch=$(date +%s)
    local current_year=$(date -u +%Y)
    local current_month=$(date -u +%m)
    
    local next_month=$((10#$current_month + 1))
    local next_year=$current_year
    if [ "$next_month" -gt 12 ]; then
        next_month=1
        next_year=$((current_year + 1))
    fi
    
    local next_month_str=$(printf "%04d-%02d-01T00:00:00Z" "$next_year" "$next_month")
    local reset_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$next_month_str" "+%s" 2>/dev/null)
    
    if [ -z "$reset_epoch" ]; then
        echo ""
        return
    fi
    
    local diff=$((reset_epoch - now_epoch))
    local days=$((diff / 86400))
    local hours=$(((diff % 86400) / 3600))
    
    if [ "$days" -gt 0 ]; then
        echo "${days}d ${hours}h"
    else
        echo "${hours}h"
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

COPILOT_P=$(jq -r '.[] | select(.provider == "copilot") | .usage.primary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)

if [ -n "$COPILOT_P" ]; then
    REM_P=$((100 - COPILOT_P))
    BAR_P=$(make_bar $REM_P)
    TIME=$(time_until_next_month)
    COLOR=$(get_color $REM_P)
    
    # 名前はアイコンで表示されるので、ラベルには数値のみ
    LABEL="${REM_P}% ${BAR_P}"
    [ -n "$TIME" ] && LABEL+=" ${TIME}"
    
    sketchybar --set $NAME label="$LABEL" label.color=$COLOR
else
    sketchybar --set $NAME label="" icon.drawing=off
fi
