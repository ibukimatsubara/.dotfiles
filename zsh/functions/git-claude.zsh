# Claude Code連携のGit関数

# Claude Codeでコミットメッセージを生成
function gcmc() {
    # ステージングされた変更を確認
    if [ -z "$(git diff --cached --name-only)" ]; then
        echo "No staged changes to commit."
        return 1
    fi
    
    # claude codeを使ってコミットメッセージを生成
    echo "Generating commit message with Claude Code..."
    
    # 変更内容を取得
    local changes=$(git diff --cached)
    local staged_files=$(git diff --cached --name-only)
    
    # claude codeでメッセージ生成（プロンプトを含む）
    local prompt="Based on the following git diff, generate a concise and descriptive commit message following conventional commits format (feat/fix/docs/style/refactor/test/chore). Just output the commit message, nothing else.

Staged files:
$staged_files

Changes:
$changes"
    
    # claude codeを呼び出してメッセージを生成
    local commit_msg=$(echo "$prompt" | claude --no-conversation 2>/dev/null)
    
    if [ -z "$commit_msg" ]; then
        echo "Failed to generate commit message. Using manual input."
        echo -n "Enter commit message: "
        read commit_msg
    else
        echo "Generated message: $commit_msg"
        echo -n "Use this message? (y/n/e to edit): "
        read response
        
        case $response in
            [Yy]* ) ;;
            [Ee]* ) 
                echo -n "Edit message: "
                read -e -i "$commit_msg" commit_msg
                ;;
            * ) 
                echo -n "Enter new message: "
                read commit_msg
                ;;
        esac
    fi
    
    # コミット実行
    git commit -m "$commit_msg"
}

# 簡易版：直接Claudeに聞く
function gcmcc() {
    # ステージングされた変更がない場合は全て追加
    if [ -z "$(git diff --cached --name-only)" ]; then
        echo "No staged changes. Staging all changes..."
        git add -A
    fi
    
    echo "Please check staged changes and provide a commit message."
    echo "Opening claude code to analyze changes..."
    
    # claudeを対話モードで開く
    claude
}