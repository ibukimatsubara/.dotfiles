# Git aliases
alias g='git'
alias gs='git status -s'
alias ga='git add'
alias gaa='git add -A'
alias gap='git add -p'
alias gc='git clone'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gb='git branch'
alias gbd='git branch -d'
alias gbD='git branch -D'
alias gpl='git pull origin'
alias gps='git push origin'
alias gpf='git push --force-with-lease'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate'
alias gla='git log --oneline --graph --decorate --all'
alias grb='git rebase'
alias grbi='git rebase -i'
alias grbc='git rebase --continue'
alias grba='git rebase --abort'
alias grs='git reset'
alias grsh='git reset --hard'
alias gsh='git stash'
alias gstp='git stash pop'
alias gstl='git stash list'

# Claude Code integration
alias gcmc='gcmc'      # Generate commit message with Claude (日本語デフォルト)
alias gcmce='gcmc -e'  # Generate commit message in English
alias gcmcj='gcmc -j'  # Generate commit message in Japanese (明示的)
alias gcmcc='gcmcc'    # Open Claude for commit message