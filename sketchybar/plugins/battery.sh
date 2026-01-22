#!/bin/bash

# マウスホバー時はバー全体を非表示
if [ "$SENDER" = "mouse.entered" ]; then
    source "$CONFIG_DIR/plugins/bar_hover.sh"
    exit 0
fi

BATTERY_INFO=$(pmset -g batt)
PERCENTAGE=$(echo "$BATTERY_INFO" | grep -o '[0-9]*%' | head -1 | tr -d '%')
CHARGING=$(echo "$BATTERY_INFO" | grep -c "AC Power")

# バーを生成 (5段階)
filled=$(( (PERCENTAGE + 10) / 20 ))
empty=$((5 - filled))
BAR=""
for ((i=0; i<filled; i++)); do BAR+="▰"; done
for ((i=0; i<empty; i++)); do BAR+="▱"; done

# 充電中は稲妻マーク追加
if [ "$CHARGING" -gt 0 ]; then
    BAR+=" ⚡"
fi

# 色を決定 (青/紫/ピンクで統一)
if [ "$PERCENTAGE" -ge 50 ]; then
    COLOR="0xff79c0ff"   # 青 (通常)
elif [ "$PERCENTAGE" -ge 20 ]; then
    COLOR="0xffbd93f9"   # 紫 (注意)
else
    COLOR="0xffff79c6"   # ピンク (低残量)
fi

sketchybar --set $NAME label="${BAR} ${PERCENTAGE}%" label.color=$COLOR
