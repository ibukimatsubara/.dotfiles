#!/bin/bash
# ポモドーロ以外のアイテムにマウスが入ったらバー全体を非表示、5秒後に再表示

HIDE_DURATION=5
LOCK_FILE="/tmp/sketchybar_hover_lock"

case "$SENDER" in
    "mouse.entered")
        # バーを非表示
        sketchybar --bar hidden=on
        
        # 既存のタイマーをキャンセル
        if [ -f "$LOCK_FILE" ]; then
            kill $(cat "$LOCK_FILE") 2>/dev/null
        fi
        
        # 5秒後に再表示（バックグラウンド）
        (
            echo $$ > "$LOCK_FILE"
            sleep $HIDE_DURATION
            sketchybar --bar hidden=off
            rm -f "$LOCK_FILE"
        ) &
        ;;
esac
