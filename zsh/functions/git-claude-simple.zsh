# シンプル版 - claudeを対話的に使う
function gcmc-simple() {
    # ステージングされた変更を確認
    if [ -z "$(git diff --cached --name-only)" ]; then
        echo "ステージングされた変更がありません。"
        return 1
    fi
    
    echo "以下の変更に対するコミットメッセージを生成します："
    echo "----------------------------------------"
    git diff --cached --stat
    echo "----------------------------------------"
    echo ""
    echo "Claude Codeを開いています..."
    echo "以下のプロンプトをコピーして使用してください："
    echo ""
    echo "以下のgit diffに基づいて、簡潔で説明的なコミットメッセージを日本語で生成してください。conventional commits形式（feat/fix/docs/style/refactor/test/chore）に従ってください。コミットメッセージのみを出力してください。"
    echo ""
    echo "変更内容："
    git diff --cached --name-only
    echo ""
    
    # claudeを開く
    claude
    
    echo ""
    echo -n "生成されたコミットメッセージを入力してください: "
    read commit_msg
    
    if [ -n "$commit_msg" ]; then
        git commit -m "$commit_msg"
    fi
}