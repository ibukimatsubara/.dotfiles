#!/bin/bash
# マウスホバー時にアイテムを一時的に非表示にする
# 5秒後に自動で再表示

HIDE_DURATION=5

case "$SENDER" in
    "mouse.entered")
        # アイテムを非表示
        sketchybar --set "$NAME" drawing=off
        
        # 5秒後に再表示（バックグラウンドで実行）
        (
            sleep $HIDE_DURATION
            sketchybar --set "$NAME" drawing=on
        ) &
        ;;
esac
