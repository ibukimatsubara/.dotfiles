#!/usr/bin/env zsh
# Main zsh configuration file that sources all modules

# Ghostty起動時にランダム壁紙を設定
if [[ "$TERM_PROGRAM" == "ghostty" ]]; then
  ~/.dotfiles/ghostty/random-wallpaper.sh >/dev/null 2>&1
fi

# VS Code
export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"

# Source configuration files
for config in ~/.dotfiles/zsh/configs/*.zsh; do
  source $config
done

# Source all aliases
for alias_file in ~/.dotfiles/zsh/aliases/*.zsh; do
  source $alias_file
done

# Source functions if they exist
if [ -d ~/.dotfiles/zsh/functions ]; then
  for func in ~/.dotfiles/zsh/functions/*.zsh; do
    source $func
  done
fi

# Load local configuration if exists
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# Initialize fnm (Node.js version manager)
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# Initialize zoxide (smart cd)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# Initialize direnv
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi
