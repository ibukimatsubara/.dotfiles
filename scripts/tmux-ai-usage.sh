#!/bin/bash
# tmuxステータスバー用のAI使用量表示スクリプト
# キャッシュを読んで残りトークン%をバーで表示

CACHE_FILE="$HOME/.cache/ai-usage.json"

# キャッシュを更新する関数
refresh_cache() {
    if command -v codexbar &> /dev/null; then
        codexbar usage --provider all --json 2>/dev/null > "$CACHE_FILE.tmp"
        if [ -s "$CACHE_FILE.tmp" ] && head -c 1 "$CACHE_FILE.tmp" | grep -q '\['; then
            mv "$CACHE_FILE.tmp" "$CACHE_FILE"
            return 0
        else
            rm -f "$CACHE_FILE.tmp"
            return 1
        fi
    fi
    return 1
}

# キャッシュが存在しない場合
if [ ! -f "$CACHE_FILE" ]; then
    echo "AI: --"
    exit 0
fi

# キャッシュが古すぎる場合（15分以上）
CACHE_AGE=$(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)))
if [ "$CACHE_AGE" -gt 900 ]; then
    echo "AI: stale"
    exit 0
fi

# jqがない場合はシンプルな出力
if ! command -v jq &> /dev/null; then
    echo "AI: ?"
    exit 0
fi

# ISO8601からリセットまでの残り時間を計算
# 使用例: time_until "2026-01-19T09:00:00Z" → "2h 30m"
# リセット時刻が過ぎている場合はキャッシュを更新して再取得（最大3回）
time_until() {
    local reset_at=$1
    local provider=$2
    local field=$3  # "primary" or "secondary"
    local retry_count=${4:-0}
    
    if [ -z "$reset_at" ] || [ "$reset_at" = "null" ]; then
        echo ""
        return
    fi
    
    # UTCとして解釈するためTZ=UTCを指定
    local reset_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$reset_at" "+%s" 2>/dev/null)
    if [ -z "$reset_epoch" ]; then
        echo ""
        return
    fi
    
    local now_epoch=$(date +%s)
    local diff=$((reset_epoch - now_epoch))
    
    # リセット時刻が過ぎている場合
    if [ "$diff" -le 0 ]; then
        if [ "$retry_count" -lt 3 ]; then
            # キャッシュを更新
            if refresh_cache; then
                # 新しいリセット時刻を取得
                local new_reset_at=$(jq -r ".[] | select(.provider == \"$provider\") | .usage.${field}.resetsAt // empty" "$CACHE_FILE" 2>/dev/null)
                if [ -n "$new_reset_at" ] && [ "$new_reset_at" != "$reset_at" ]; then
                    # 新しい時刻で再計算
                    time_until "$new_reset_at" "$provider" "$field" $((retry_count + 1))
                    return
                fi
            fi
        fi
        # 3回試しても更新できない場合は0mを返す
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

# 次の月初(1日 00:00 UTC)までの残り時間を計算
# Copilot用（月次リセット）
time_until_next_month() {
    local now_epoch=$(date +%s)
    
    # 現在の年月を取得
    local current_year=$(date -u +%Y)
    local current_month=$(date -u +%m)
    
    # 次の月を計算
    local next_month=$((10#$current_month + 1))
    local next_year=$current_year
    if [ "$next_month" -gt 12 ]; then
        next_month=1
        next_year=$((current_year + 1))
    fi
    
    # 次の月初のepochを計算 (UTC)
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

# 残り%からバーを生成 (5段階 + %)
# 使用例: make_bar 93 "2026-01-19T09:00:00Z" "claude" "primary" → "93% ▰▰▰▰▱ 2h 30m"
make_bar() {
    local remaining=$1
    local reset_at=$2
    local provider=$3
    local field=$4
    local filled=$(( (remaining + 10) / 20 ))  # 5段階に変換
    local empty=$((5 - filled))
    local bar=""
    
    # 色を残り%で決定 (ピンク/青ベース)
    local color
    if [ "$remaining" -ge 50 ]; then
        color="#79c0ff"    # 青 (余裕あり)
    elif [ "$remaining" -ge 20 ]; then
        color="#ff79c6"    # ピンク (注意)
    else
        color="#ff5555"    # 赤 (危険)
    fi
    
    bar+="#[fg=$color]${remaining}%#[fg=default] "
    bar+="#[fg=$color]"
    for ((i=0; i<filled; i++)); do bar+="▰"; done
    bar+="#[fg=colour240]"
    for ((i=0; i<empty; i++)); do bar+="▱"; done
    bar+="#[fg=default]"
    
    # リセット時刻があれば追加
    local time_left=$(time_until "$reset_at" "$provider" "$field")
    if [ -n "$time_left" ]; then
        bar+=" #[fg=colour245]${time_left}#[fg=default]"
    fi
    
    echo "$bar"
}

# JSONをパースして表示
OUTPUT=""

# Claude Code
CLAUDE_PRIMARY=$(jq -r '.[] | select(.provider == "claude") | .usage.primary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)
CLAUDE_SECONDARY=$(jq -r '.[] | select(.provider == "claude") | .usage.secondary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)
CLAUDE_RESET_P=$(jq -r '.[] | select(.provider == "claude") | .usage.primary.resetsAt // empty' "$CACHE_FILE" 2>/dev/null)
CLAUDE_RESET_S=$(jq -r '.[] | select(.provider == "claude") | .usage.secondary.resetsAt // empty' "$CACHE_FILE" 2>/dev/null)
if [ -n "$CLAUDE_PRIMARY" ]; then
    CLAUDE_REM_P=$((100 - CLAUDE_PRIMARY))
    CLAUDE_REM_S=$((100 - CLAUDE_SECONDARY))
    BAR_P=$(make_bar $CLAUDE_REM_P "$CLAUDE_RESET_P" "claude" "primary")
    BAR_S=$(make_bar $CLAUDE_REM_S "$CLAUDE_RESET_S" "claude" "secondary")
    OUTPUT+="#[fg=#ff79c6]Claude#[fg=default] ${BAR_P} ${BAR_S}  "
fi

# Codex (OpenAI) - disabled, uncomment to enable
# CODEX_PRIMARY=$(jq -r '.[] | select(.provider == "codex") | .usage.primary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)
# CODEX_SECONDARY=$(jq -r '.[] | select(.provider == "codex") | .usage.secondary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)
# CODEX_RESET_P=$(jq -r '.[] | select(.provider == "codex") | .usage.primary.resetsAt // empty' "$CACHE_FILE" 2>/dev/null)
# CODEX_RESET_S=$(jq -r '.[] | select(.provider == "codex") | .usage.secondary.resetsAt // empty' "$CACHE_FILE" 2>/dev/null)
# if [ -n "$CODEX_PRIMARY" ]; then
#     CODEX_REM_P=$((100 - CODEX_PRIMARY))
#     CODEX_REM_S=$((100 - CODEX_SECONDARY))
#     BAR_P=$(make_bar $CODEX_REM_P "$CODEX_RESET_P" "codex" "primary")
#     BAR_S=$(make_bar $CODEX_REM_S "$CODEX_RESET_S" "codex" "secondary")
#     OUTPUT+="#[fg=#79c0ff]Codex#[fg=default] ${BAR_P} ${BAR_S}  "
# fi

# Gemini - disabled, uncomment to enable
# GEMINI_PRIMARY=$(jq -r '.[] | select(.provider == "gemini") | .usage.primary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)
# GEMINI_RESET_P=$(jq -r '.[] | select(.provider == "gemini") | .usage.primary.resetsAt // empty' "$CACHE_FILE" 2>/dev/null)
# if [ -n "$GEMINI_PRIMARY" ]; then
#     GEMINI_REM=$((100 - GEMINI_PRIMARY))
#     BAR=$(make_bar $GEMINI_REM "$GEMINI_RESET_P" "gemini" "primary")
#     OUTPUT+="#[fg=#bd93f9]Gemini#[fg=default] ${BAR}  "
# fi

# GitHub Copilot (月次リセット、primaryのみ表示)
COPILOT_PRIMARY=$(jq -r '.[] | select(.provider == "copilot") | .usage.primary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)
if [ -n "$COPILOT_PRIMARY" ]; then
    COPILOT_REM=$((100 - COPILOT_PRIMARY))
    # 次の月初までの残り時間を計算
    COPILOT_RESET=$(time_until_next_month)
    BAR=$(make_bar $COPILOT_REM "" "" "")
    # リセット時刻を手動で追加
    if [ -n "$COPILOT_RESET" ]; then
        OUTPUT+="#[fg=#8be9fd]Copilot#[fg=default] ${BAR} #[fg=colour245]${COPILOT_RESET}#[fg=default]  "
    else
        OUTPUT+="#[fg=#8be9fd]Copilot#[fg=default] ${BAR}  "
    fi
fi

# Zed AI
ZAI_PRIMARY=$(jq -r '.[] | select(.provider == "zai") | .usage.primary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)
ZAI_RESET_P=$(jq -r '.[] | select(.provider == "zai") | .usage.primary.resetsAt // empty' "$CACHE_FILE" 2>/dev/null)
if [ -n "$ZAI_PRIMARY" ]; then
    ZAI_REM=$((100 - ZAI_PRIMARY))
    BAR=$(make_bar $ZAI_REM "$ZAI_RESET_P" "zai" "primary")
    OUTPUT+="#[fg=#ffb86c]Zed#[fg=default] ${BAR}  "
fi

if [ -z "$OUTPUT" ]; then
    echo "AI: --"
else
    echo "$OUTPUT"
fi
