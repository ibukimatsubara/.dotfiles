#!/bin/bash
# tmuxステータスバー用のAI使用量表示スクリプト
# キャッシュを読んで残りトークン%をバーで表示

CACHE_FILE="$HOME/.cache/ai-usage.json"

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

# 残り%からバーを生成 (5段階 + %)
# 使用例: make_bar 93 → "93% ▰▰▰▰▱"
make_bar() {
    local remaining=$1
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
    
    echo "$bar"
}

# JSONをパースして表示
OUTPUT=""

# Claude Code
CLAUDE_PRIMARY=$(jq -r '.[] | select(.provider == "claude") | .usage.primary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)
CLAUDE_SECONDARY=$(jq -r '.[] | select(.provider == "claude") | .usage.secondary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)
if [ -n "$CLAUDE_PRIMARY" ]; then
    CLAUDE_REM_P=$((100 - CLAUDE_PRIMARY))
    CLAUDE_REM_S=$((100 - CLAUDE_SECONDARY))
    BAR_P=$(make_bar $CLAUDE_REM_P)
    BAR_S=$(make_bar $CLAUDE_REM_S)
    OUTPUT+="#[fg=#ff79c6]Claude#[fg=default] ${BAR_P} ${BAR_S}  "
fi

# Codex (OpenAI) - disabled, uncomment to enable
# CODEX_PRIMARY=$(jq -r '.[] | select(.provider == "codex") | .usage.primary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)
# CODEX_SECONDARY=$(jq -r '.[] | select(.provider == "codex") | .usage.secondary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)
# if [ -n "$CODEX_PRIMARY" ]; then
#     CODEX_REM_P=$((100 - CODEX_PRIMARY))
#     CODEX_REM_S=$((100 - CODEX_SECONDARY))
#     BAR_P=$(make_bar $CODEX_REM_P)
#     BAR_S=$(make_bar $CODEX_REM_S)
#     OUTPUT+="#[fg=#79c0ff]Codex#[fg=default] ${BAR_P} ${BAR_S}  "
# fi

# Gemini - disabled, uncomment to enable
# GEMINI_PRIMARY=$(jq -r '.[] | select(.provider == "gemini") | .usage.primary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)
# if [ -n "$GEMINI_PRIMARY" ]; then
#     GEMINI_REM=$((100 - GEMINI_PRIMARY))
#     BAR=$(make_bar $GEMINI_REM)
#     OUTPUT+="#[fg=#bd93f9]Gemini#[fg=default] ${BAR}  "
# fi

# GitHub Copilot
COPILOT_PRIMARY=$(jq -r '.[] | select(.provider == "copilot") | .usage.primary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)
COPILOT_SECONDARY=$(jq -r '.[] | select(.provider == "copilot") | .usage.secondary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)
if [ -n "$COPILOT_PRIMARY" ]; then
    COPILOT_REM_P=$((100 - COPILOT_PRIMARY))
    BAR_P=$(make_bar $COPILOT_REM_P)
    if [ -n "$COPILOT_SECONDARY" ]; then
        COPILOT_REM_S=$((100 - COPILOT_SECONDARY))
        BAR_S=$(make_bar $COPILOT_REM_S)
        OUTPUT+="#[fg=#8be9fd]Copilot#[fg=default] ${BAR_P} ${BAR_S}  "
    else
        OUTPUT+="#[fg=#8be9fd]Copilot#[fg=default] ${BAR_P}  "
    fi
fi

# Zed AI
ZAI_PRIMARY=$(jq -r '.[] | select(.provider == "zai") | .usage.primary.usedPercent // empty' "$CACHE_FILE" 2>/dev/null)
if [ -n "$ZAI_PRIMARY" ]; then
    ZAI_REM=$((100 - ZAI_PRIMARY))
    BAR=$(make_bar $ZAI_REM)
    OUTPUT+="#[fg=#ffb86c]Zed#[fg=default] ${BAR}  "
fi

if [ -z "$OUTPUT" ]; then
    echo "AI: --"
else
    echo "$OUTPUT"
fi
