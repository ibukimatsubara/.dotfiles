#!/bin/bash

# マウス位置を監視してSketchyBarの表示/非表示を切り替え
# BAR_HEIGHT以下にマウスがあれば隠す

BAR_HEIGHT=25

while true; do
    # マウスのY座標を取得 (画面上部が0)
    MOUSE_Y=$(osascript -e 'tell application "System Events" to return (do shell script "echo $(/usr/bin/python3 -c \"import Quartz; print(int(Quartz.NSEvent.mouseLocation().y))\")")')
    
    # 画面の高さを取得
    SCREEN_HEIGHT=$(osascript -e 'tell application "Finder" to get bounds of window of desktop' | cut -d',' -f4 | tr -d ' ')
    
    # Y座標を上からの距離に変換 (macOSは下が0なので)
    MOUSE_FROM_TOP=$((SCREEN_HEIGHT - MOUSE_Y))
    
    if [ "$MOUSE_FROM_TOP" -le "$BAR_HEIGHT" ]; then
        # マウスがバー領域内 → 隠す
        sketchybar --bar color=0x00000000 --set '/.*/' label.color=0x00000000 icon.color=0x00000000
    else
        # マウスがバー領域外 → 表示
        sketchybar --bar color=0xcc282a36 --set '/.*/' label.color=0xfff8f8f2 icon.color=0xfff8f8f2
    fi
    
    sleep 0.1
done
