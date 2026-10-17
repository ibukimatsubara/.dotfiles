#!/usr/bin/env zsh
# Main zsh configuration file that sources all modules

# PATH needed before shared plugins initialize.
source ~/.dotfiles/platforms/common/zsh.zsh

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

# Load only this OS's overrides before machine-local configuration.
case "$OSTYPE" in
  darwin*) source ~/.dotfiles/platforms/macos/zsh.zsh ;;
  linux*) source ~/.dotfiles/platforms/ubuntu/zsh.zsh ;;
esac

# Load local configuration if exists
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# Initialize fnm as the sole Node.js version manager, after local PATH setup.
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
