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
alias va='source .venv/bin/activate'
alias vd='deactivate'
alias vc='python3 -m venv .venv'
# julia
alias j='julia'
# singularity
alias sec='singularity exec --nv Singularity.sif'
alias sb='singularity build --fakeroot Singularity.def Singularity.sif'
# atcoder
alias ac='(){acc new abc$1 -c all}'
alias at='(){oj t -c "python3 ./$1/main.py" -d ./$1/tests/}'
alias as='(){cd $1;acc s ./main.py -- --guess-python-interpreter pypy -w 0 -y;cd -}'


#--------------------- prompt theme -----------------

theme=simple

if [ -f ~/.dotfiles/theme/$theme ]; then
  . ~/.dotfiles/theme/$theme
else
  echo "not find theme file !"
fi
