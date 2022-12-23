#----------------------- zsh setting -----------------
setopt sharehistory
setopt auto_cd
setopt correct

#------------------------ alias -----------------------
alias c='clear'
alias ll='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lal='ls -la'
# tmux
alias t='tmux'
alias tn='tmux new -s'
alias tk='tmux kill-session -t'
alias tt='tmux a -t'
alias tl='tmux ls'
# vim
alias v='nvim'
# git
alias g='git'
alias gst='git status -s'
alias ga='git add'
alias gc='git clone'
alias gcm='git commit -m'
alias gco='git checkout'
alias gb='git branch'
alias gpl='git pull origin'
alias gps='git push origin'
# venv 
alias va='source venv/bin/activate'
alias vd='deactivate'
alias vc='python -m venv venv'
# julia
alias j='julia'
# singularity
alias sec='singularity exec --nv Singularity.sif'
alias sb='singularity build --fakeroot Singularity.def Singularity.sif'

#--------------------- prompt theme -----------------

theme=simple_cyberpunk

if [ -f ~/dotfiles/zsh_theme/$theme ]; then
  . ~/dotfiles/zsh_theme/$theme
else
  echo "not find theme file !"
fi
