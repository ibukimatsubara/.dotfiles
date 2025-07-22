# Prompt theme configuration
theme=simple

if [ -f ~/.dotfiles/theme/$theme ]; then
  . ~/.dotfiles/theme/$theme
else
  echo "Theme file not found: $theme"
fi