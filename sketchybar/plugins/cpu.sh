#!/bin/bash

# マウスホバー時はバー全体を非表示
if [ "$SENDER" = "mouse.entered" ]; then
    source "$CONFIG_DIR/plugins/bar_hover.sh"
    exit 0
fi

# 履歴ファイル
HISTORY_FILE="/tmp/sketchybar_cpu_history"

# 現在のCPU使用率を取得
CPU=$(top -l 1 | grep "CPU usage" | awk '{print int($3)}')

# 履歴を読み込み (最大8個)
if [ -f "$HISTORY_FILE" ]; then
    HISTORY=$(cat "$HISTORY_FILE")
else
    HISTORY=""
fi

# 新しい値を追加して古いのを削除
HISTORY="$HISTORY $CPU"
HISTORY=$(echo $HISTORY | tr ' ' '\n' | tail -8 | tr '\n' ' ')
echo "$HISTORY" > "$HISTORY_FILE"

# ブレイルスパークライン文字 (8段階)
# ⣀ ⣤ ⣶ ⣿ or ▁▂▃▄▅▆▇█
chars=(⡀ ⣀ ⣠ ⣤ ⣴ ⣶ ⣾ ⣿)

# 履歴からスパークラインを生成
SPARK=""
for val in $HISTORY; do
    idx=$(( val * 7 / 100 ))
    if [ $idx -gt 7 ]; then idx=7; fi
    if [ $idx -lt 0 ]; then idx=0; fi
    SPARK+="${chars[$idx]}"
done

# 8文字に満たない場合は空白文字で埋める
while [ ${#SPARK} -lt 8 ]; do
    SPARK="⡀${SPARK}"
done

# 色を決定 (負荷に応じて)
if [ "$CPU" -ge 80 ]; then
    COLOR="0xffff5555"   # 赤 (高負荷)
elif [ "$CPU" -ge 50 ]; then
    COLOR="0xffbd93f9"   # 紫 (中負荷)
else
    COLOR="0xff79c0ff"   # 青 (通常)
fi

sketchybar --set $NAME label="${SPARK} ${CPU}%" label.color=$COLOR
