#!/bin/bash
# AI使用量をキャッシュするスクリプト
# 10分ごとにcronまたはlaunchdで実行

CACHE_FILE="$HOME/.cache/ai-usage.json"
CACHE_DIR="$(dirname "$CACHE_FILE")"

# キャッシュディレクトリ作成
mkdir -p "$CACHE_DIR"

# codexbarが存在するか確認
if ! command -v codexbar &> /dev/null; then
    echo '{"error": "codexbar not found"}' > "$CACHE_FILE"
    exit 1
fi

# 使用量を取得してキャッシュ (stderrのエラーは無視、stdoutのJSONのみ保存)
codexbar usage --provider all --json 2>/dev/null > "$CACHE_FILE.tmp"

# JSONが有効かチェック（配列で始まるか）
if [ -s "$CACHE_FILE.tmp" ] && head -c 1 "$CACHE_FILE.tmp" | grep -q '\['; then
    mv "$CACHE_FILE.tmp" "$CACHE_FILE"
else
    rm -f "$CACHE_FILE.tmp"
fi
