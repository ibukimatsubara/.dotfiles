# デバッグ版のgcmc関数
function gcmc-debug() {
    echo "=== Debug Mode ==="
    
    # ステージングされた変更を確認
    if [ -z "$(git diff --cached --name-only)" ]; then
        echo "No staged changes."
        return 1
    fi
    
    echo "Staged files:"
    git diff --cached --name-only
    
    # プロンプト作成
    local staged_files=$(git diff --cached --name-only)
    local prompt="以下のgit diffに基づいて、簡潔で説明的なコミットメッセージを日本語で生成してください。conventional commits形式（feat/fix/docs/style/refactor/test/chore）に従ってください。コミットメッセージのみを出力してください。

ステージングされたファイル:
$staged_files"
    
    echo -e "\n=== Prompt ==="
    echo "$prompt"
    
    echo -e "\n=== Testing Claude CLI ==="
    echo "Simple test:"
    echo "Hello" | claude --print
    
    echo -e "\n=== Trying to generate commit message ==="
    local commit_msg=$(echo "$prompt" | claude --print 2>&1)
    echo "Result: $commit_msg"
    
    if [ -z "$commit_msg" ]; then
        echo "Failed to generate commit message"
    fi
}