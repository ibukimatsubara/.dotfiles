#!/usr/bin/env zsh
# Main zsh configuration file that sources all modules

# Add dotfiles bin directories to PATH
export PATH="$HOME/.dotfiles/tmux-claude/bin:$PATH"

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