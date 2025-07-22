# Claude Code連携のGit関数

# デフォルト言語設定（環境変数で上書き可能）
: ${GIT_COMMIT_LANG:="ja"}

# Claude Codeでコミットメッセージを生成
function gcmc() {
    # 言語オプションの処理
    local lang=$GIT_COMMIT_LANG
    if [[ "$1" == "-e" ]] || [[ "$1" == "--english" ]]; then
        lang="en"
        shift
    elif [[ "$1" == "-j" ]] || [[ "$1" == "--japanese" ]]; then
        lang="ja"
        shift
    fi
    
    # ステージングされた変更を確認
    if [ -z "$(git diff --cached --name-only)" ]; then
        if [[ "$lang" == "ja" ]]; then
            echo "ステージングされた変更がありません。"
        else
            echo "No staged changes to commit."
        fi
        return 1
    fi
    
    # claude codeを使ってコミットメッセージを生成
    if [[ "$lang" == "ja" ]]; then
        echo "Claude Codeでコミットメッセージを生成中..."
    else
        echo "Generating commit message with Claude Code..."
    fi
    
    # 変更内容を取得
    local changes=$(git diff --cached)
    local staged_files=$(git diff --cached --name-only)
    
    # 言語別のプロンプト
    local prompt
    if [[ "$lang" == "ja" ]]; then
        prompt="以下のgit diffに基づいて、簡潔で説明的なコミットメッセージを日本語で生成してください。conventional commits形式（feat/fix/docs/style/refactor/test/chore）に従ってください。コミットメッセージのみを出力してください。

ステージングされたファイル:
$staged_files

変更内容:
$changes"
    else
        prompt="Based on the following git diff, generate a concise and descriptive commit message following conventional commits format (feat/fix/docs/style/refactor/test/chore). Just output the commit message, nothing else.

Staged files:
$staged_files

Changes:
$changes"
    fi
    
    # claude codeを呼び出してメッセージを生成
    local commit_msg=$(echo "$prompt" | claude --print 2>/dev/null)
    
    if [ -z "$commit_msg" ]; then
        if [[ "$lang" == "ja" ]]; then
            echo "コミットメッセージの生成に失敗しました。手動で入力してください。"
            echo -n "コミットメッセージを入力: "
        else
            echo "Failed to generate commit message. Using manual input."
            echo -n "Enter commit message: "
        fi
        read commit_msg
    else
        echo "Generated message: $commit_msg"
        if [[ "$lang" == "ja" ]]; then
            echo -n "このメッセージを使用しますか？ (y/n/e で編集): "
        else
            echo -n "Use this message? (y/n/e to edit): "
        fi
        read response
        
        case $response in
            [Yy]* ) ;;
            [Ee]* ) 
                if [[ "$lang" == "ja" ]]; then
                    echo -n "メッセージを編集: "
                else
                    echo -n "Edit message: "
                fi
                read -e -i "$commit_msg" commit_msg
                ;;
            * ) 
                if [[ "$lang" == "ja" ]]; then
                    echo -n "新しいメッセージを入力: "
                else
                    echo -n "Enter new message: "
                fi
                read commit_msg
                ;;
        esac
    fi
    
    # コミット実行
    git commit -m "$commit_msg"
}

# 英語版のショートカット
function gcmce() {
    gcmc -e "$@"
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