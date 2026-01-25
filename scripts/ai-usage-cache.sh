#!/bin/bash
# AI使用量をキャッシュするスクリプト
# Claude OAuth API と GitHub Copilot Internal API を直接呼び出し (codexbar不要)
# launchdで定期実行

set -euo pipefail

CACHE_FILE="$HOME/.cache/ai-usage.json"
CACHE_DIR="$(dirname "$CACHE_FILE")"
COPILOT_TOKEN_FILE="$HOME/.config/copilot-token"

# キャッシュディレクトリ作成
mkdir -p "$CACHE_DIR"

# Keychainからclaude認証情報を取得
get_claude_credentials() {
    security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null
}

# トークンの有効期限を確認
is_token_expired() {
    local creds="$1"
    local expires_at
    expires_at=$(echo "$creds" | jq -r '.claudeAiOauth.expiresAt // 0')
    
    if [ "$expires_at" = "0" ] || [ "$expires_at" = "null" ]; then
        return 0  # expired (or invalid)
    fi
    
    local now_ms=$(($(date +%s) * 1000))
    if [ "$expires_at" -lt "$now_ms" ]; then
        return 0  # expired
    fi
    
    return 1  # not expired
}

# claudeコマンドを起動してトークンをリフレッシュ
refresh_claude_token() {
    # claude を起動して数秒待ってからkill (トークンリフレッシュのため)
    claude </dev/null >/dev/null 2>&1 &
    local pid=$!
    sleep 3
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
    sleep 1  # Keychainに書き込まれるのを待つ
}

# Claude使用量を取得
fetch_claude_usage() {
    local creds
    creds=$(get_claude_credentials) || {
        echo '{"provider":"claude","source":"oauth","error":{"message":"No Claude credentials found in Keychain. Run claude to authenticate.","kind":"provider","code":1}}'
        return
    }
    
    # トークンの有効期限確認
    if is_token_expired "$creds"; then
        # 自動リフレッシュを試行
        refresh_claude_token
        # 再度取得
        creds=$(get_claude_credentials) || {
            echo '{"provider":"claude","source":"oauth","error":{"message":"Token refresh failed","kind":"auth","code":2}}'
            return
        }
        # まだ期限切れならエラー
        if is_token_expired "$creds"; then
            echo '{"provider":"claude","source":"oauth","error":{"message":"Token expired. Run claude to refresh.","kind":"auth","code":2}}'
            return
        fi
    fi
    
    local token
    token=$(echo "$creds" | jq -r '.claudeAiOauth.accessToken // empty')
    
    if [ -z "$token" ]; then
        echo '{"provider":"claude","source":"oauth","error":{"message":"No access token found","kind":"auth","code":3}}'
        return
    fi
    
    # OAuth usage API呼び出し
    local response http_code
    response=$(curl -s -w "\n%{http_code}" "https://api.anthropic.com/api/oauth/usage" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "Content-Type: application/json" \
        -H "User-Agent: dotfiles-ai-usage" 2>/dev/null) || {
        echo '{"provider":"claude","source":"oauth","error":{"message":"Network error","kind":"network","code":4}}'
        return
    }
    
    # HTTPステータスコードを分離
    http_code=$(echo "$response" | tail -1)
    response=$(echo "$response" | sed '$d')
    
    case "$http_code" in
        200)
            # 成功
            ;;
        401)
            echo '{"provider":"claude","source":"oauth","error":{"message":"Token expired or invalid. Run claude to refresh.","kind":"auth","code":5}}'
            return
            ;;
        *)
            echo "{\"provider\":\"claude\",\"source\":\"oauth\",\"error\":{\"message\":\"API error: HTTP $http_code\",\"kind\":\"api\",\"code\":6}}"
            return
            ;;
    esac
    
    # レスポンスを解析
    local five_hour seven_day
    five_hour=$(echo "$response" | jq -r '.five_hour // empty' 2>/dev/null)
    seven_day=$(echo "$response" | jq -r '.seven_day // empty' 2>/dev/null)
    
    if [ -z "$five_hour" ] && [ -z "$seven_day" ]; then
        echo '{"provider":"claude","source":"oauth","error":{"message":"Invalid API response","kind":"parse","code":7}}'
        return
    fi
    
    # 使用率を計算 (utilization は使用率なので usedPercent としてそのまま使用)
    local primary_used=0 primary_reset="" secondary_used=0 secondary_reset=""
    
    if [ -n "$five_hour" ] && [ "$five_hour" != "null" ]; then
        primary_used=$(echo "$five_hour" | jq -r '.utilization // 0')
        primary_reset=$(echo "$five_hour" | jq -r '.resets_at // empty')
        # resets_at をISO8601形式に正規化
        if [ -n "$primary_reset" ]; then
            # タイムゾーン付きを UTC の Z 形式に変換
            primary_reset=$(echo "$primary_reset" | sed 's/+00:00$/Z/')
        fi
    fi
    
    if [ -n "$seven_day" ] && [ "$seven_day" != "null" ]; then
        secondary_used=$(echo "$seven_day" | jq -r '.utilization // 0')
        secondary_reset=$(echo "$seven_day" | jq -r '.resets_at // empty')
        if [ -n "$secondary_reset" ]; then
            secondary_reset=$(echo "$secondary_reset" | sed 's/+00:00$/Z/')
        fi
    fi
    
    # codexbar互換のJSON形式で出力
    local updated_at
    updated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # 小数点を整数に変換
    primary_used=$(printf "%.0f" "$primary_used")
    secondary_used=$(printf "%.0f" "$secondary_used")
    
    cat <<EOF
{
  "provider": "claude",
  "version": "self-hosted",
  "source": "oauth",
  "usage": {
    "updatedAt": "$updated_at",
    "loginMethod": "Claude Max",
    "primary": {
      "usedPercent": $primary_used,
      "windowMinutes": 300,
      "resetsAt": "$primary_reset"
    },
    "secondary": {
      "usedPercent": $secondary_used,
      "windowMinutes": 10080,
      "resetsAt": "$secondary_reset"
    }
  }
}
EOF
}

# Copilot使用量を取得
fetch_copilot_usage() {
    # トークンファイルを確認
    if [ ! -f "$COPILOT_TOKEN_FILE" ]; then
        echo '{"provider":"copilot","source":"api","error":{"message":"No Copilot token. Run scripts/copilot-auth.sh to authenticate.","kind":"provider","code":1}}'
        return
    fi
    
    local token
    token=$(cat "$COPILOT_TOKEN_FILE" 2>/dev/null)
    
    if [ -z "$token" ]; then
        echo '{"provider":"copilot","source":"api","error":{"message":"Empty token file","kind":"auth","code":2}}'
        return
    fi
    
    # Copilot Internal API呼び出し
    local response http_code
    response=$(curl -s -w "\n%{http_code}" "https://api.github.com/copilot_internal/user" \
        -H "Authorization: token $token" \
        -H "Accept: application/json" \
        -H "Editor-Version: vscode/1.96.2" \
        -H "Editor-Plugin-Version: copilot-chat/0.26.7" \
        -H "User-Agent: GitHubCopilotChat/0.26.7" \
        -H "X-Github-Api-Version: 2025-04-01" 2>/dev/null) || {
        echo '{"provider":"copilot","source":"api","error":{"message":"Network error","kind":"network","code":3}}'
        return
    }
    
    # HTTPステータスコードを分離
    http_code=$(echo "$response" | tail -1)
    response=$(echo "$response" | sed '$d')
    
    case "$http_code" in
        200)
            # 成功
            ;;
        401|403)
            echo '{"provider":"copilot","source":"api","error":{"message":"Token expired or invalid. Run scripts/copilot-auth.sh to re-authenticate.","kind":"auth","code":4}}'
            return
            ;;
        *)
            echo "{\"provider\":\"copilot\",\"source\":\"api\",\"error\":{\"message\":\"API error: HTTP $http_code\",\"kind\":\"api\",\"code\":5}}"
            return
            ;;
    esac
    
    # レスポンスを解析
    # quota_snapshots.premium_interactions と quota_snapshots.chat から使用量を取得
    local primary_remaining secondary_remaining plan
    
    # premiumInteractions または premium_interactions を試す
    primary_remaining=$(echo "$response" | jq -r '.quota_snapshots.premium_interactions.percent_remaining // .quotaSnapshots.premiumInteractions.percentRemaining // empty' 2>/dev/null)
    secondary_remaining=$(echo "$response" | jq -r '.quota_snapshots.chat.percent_remaining // .quotaSnapshots.chat.percentRemaining // empty' 2>/dev/null)
    plan=$(echo "$response" | jq -r '.copilot_plan // .copilotPlan // "unknown"' 2>/dev/null)
    
    # 使用率を計算 (remaining -> used)
    local primary_used=0 secondary_used=0
    
    if [ -n "$primary_remaining" ] && [ "$primary_remaining" != "null" ]; then
        # 小数点を整数に変換
        primary_remaining=$(printf "%.0f" "$primary_remaining")
        primary_used=$((100 - primary_remaining))
        [ "$primary_used" -lt 0 ] && primary_used=0
    fi
    
    if [ -n "$secondary_remaining" ] && [ "$secondary_remaining" != "null" ]; then
        secondary_remaining=$(printf "%.0f" "$secondary_remaining")
        secondary_used=$((100 - secondary_remaining))
        [ "$secondary_used" -lt 0 ] && secondary_used=0
    fi
    
    local updated_at
    updated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat <<EOF
{
  "provider": "copilot",
  "version": "self-hosted",
  "source": "api",
  "usage": {
    "updatedAt": "$updated_at",
    "loginMethod": "$plan",
    "primary": {
      "usedPercent": $primary_used,
      "windowMinutes": null,
      "resetsAt": null
    },
    "secondary": {
      "usedPercent": $secondary_used,
      "windowMinutes": null,
      "resetsAt": null
    }
  }
}
EOF
}

# メイン処理
main() {
    local providers=()
    
    # Claude使用量を取得
    local claude_data
    claude_data=$(fetch_claude_usage)
    providers+=("$claude_data")
    
    # Copilot使用量を取得
    local copilot_data
    copilot_data=$(fetch_copilot_usage)
    providers+=("$copilot_data")
    
    # JSON配列を構築
    local result="["
    local first=true
    for provider in "${providers[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            result+=","
        fi
        result+="$provider"
    done
    result+="]"
    
    # JSONが有効か確認して保存
    if echo "$result" | jq . >/dev/null 2>&1; then
        echo "$result" > "$CACHE_FILE.tmp"
        mv "$CACHE_FILE.tmp" "$CACHE_FILE"
        echo "Cache updated: $CACHE_FILE"
    else
        echo "Error: Invalid JSON generated" >&2
        echo "$result" >&2
        exit 1
    fi
}

main
