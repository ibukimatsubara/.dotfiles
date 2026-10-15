# Keep native Zsh completion when the legacy nvm Bash completion loader is gone.
if [[ -o interactive ]] && (( ! ${+_comps} )); then
  autoload -Uz compinit
  compinit
fi
