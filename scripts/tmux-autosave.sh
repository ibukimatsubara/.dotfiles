#!/usr/bin/env bash
# tmux-autosave.sh - status off でも continuum の自動保存を実行
# status bar が off の場合、status-right のスクリプトが実行されないため、
# このスクリプトで定期的に保存を行う

SAVE_INTERVAL="${1:-900}"  # デフォルト15分（900秒）
SAVE_SCRIPT="$HOME/.tmux/plugins/tmux-continuum/scripts/continuum_save.sh"

# tmuxサーバーが動作している間だけ実行
while tmux list-sessions &>/dev/null; do
    if [ -x "$SAVE_SCRIPT" ]; then
        "$SAVE_SCRIPT"
    fi
    sleep "$SAVE_INTERVAL"
done
