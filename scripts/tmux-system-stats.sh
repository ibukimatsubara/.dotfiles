#!/bin/bash
# tmuxステータスバー用のシステム統計表示スクリプト
# CPU/MEM: スパークライン + %、BAT: バー + %

# 履歴ファイル
CPU_HISTORY="/tmp/tmux_cpu_history"
MEM_HISTORY="/tmp/tmux_mem_history"

# ブレイルスパークライン文字 (8段階)
chars=(⡀ ⣀ ⣠ ⣤ ⣴ ⣶ ⣾ ⣿)

# 値からスパークライン1文字を生成
get_spark_char() {
    local val=$1
    local idx=$(( val * 7 / 100 ))
    if [ $idx -gt 7 ]; then idx=7; fi
    if [ $idx -lt 0 ]; then idx=0; fi
    echo "${chars[$idx]}"
}

# 色を決定 (tmux形式)
get_color() {
    local val=$1
    if [ "$val" -ge 80 ]; then
        echo "#ff5555"    # 赤 (高負荷)
    elif [ "$val" -ge 50 ]; then
        echo "#bd93f9"    # 紫 (中負荷)
    else
        echo "#79c0ff"    # 青 (通常)
    fi
}

# 履歴からスパークラインを生成
make_sparkline() {
    local history_file=$1
    local current_val=$2
    
    # 履歴を読み込み
    if [ -f "$history_file" ]; then
        HISTORY=$(cat "$history_file")
    else
        HISTORY=""
    fi
    
    # 新しい値を追加して古いのを削除 (8個保持)
    HISTORY="$HISTORY $current_val"
    HISTORY=$(echo $HISTORY | tr ' ' '\n' | tail -8 | tr '\n' ' ')
    echo "$HISTORY" > "$history_file"
    
    # スパークライン生成
    SPARK=""
    for val in $HISTORY; do
        SPARK+=$(get_spark_char $val)
    done
    
    # 8文字に満たない場合は埋める
    while [ ${#SPARK} -lt 8 ]; do
        SPARK="⡀${SPARK}"
    done
    
    echo "$SPARK"
}

# バーを生成 (5段階)
make_bar() {
    local val=$1
    local filled=$(( (val + 10) / 20 ))
    local empty=$((5 - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="▰"; done
    for ((i=0; i<empty; i++)); do bar+="▱"; done
    echo "$bar"
}

# CPU使用率を取得
CPU=$(top -l 1 | grep "CPU usage" | awk '{print int($3)}')
CPU_SPARK=$(make_sparkline "$CPU_HISTORY" "$CPU")
CPU_COLOR=$(get_color $CPU)

# メモリ使用率を取得
MEM=$(memory_pressure | grep "System-wide memory free percentage" | awk '{print 100 - int($5)}')
MEM_SPARK=$(make_sparkline "$MEM_HISTORY" "$MEM")
MEM_COLOR=$(get_color $MEM)

# バッテリー情報を取得
BATTERY_INFO=$(pmset -g batt)
BAT=$(echo "$BATTERY_INFO" | grep -o '[0-9]*%' | head -1 | tr -d '%')
CHARGING=$(echo "$BATTERY_INFO" | grep -c "AC Power")
BAT_BAR=$(make_bar $BAT)

# バッテリー色
if [ "$BAT" -ge 50 ]; then
    BAT_COLOR="#79c0ff"
elif [ "$BAT" -ge 20 ]; then
    BAT_COLOR="#bd93f9"
else
    BAT_COLOR="#ff79c6"
fi

# 充電中マーク
if [ "$CHARGING" -gt 0 ]; then
    BAT_BAR+=" ⚡"
fi

# 出力
echo "#[fg=colour245]CPU#[fg=default] #[fg=${CPU_COLOR}]${CPU_SPARK} ${CPU}%#[fg=default]  #[fg=colour245]MEM#[fg=default] #[fg=${MEM_COLOR}]${MEM_SPARK} ${MEM}%#[fg=default]  #[fg=colour245]BAT#[fg=default] #[fg=${BAT_COLOR}]${BAT_BAR} ${BAT}%#[fg=default]"
