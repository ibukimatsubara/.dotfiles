# Development tool aliases

# Editor
alias v='nvim'
alias vi='nvim'
alias vim='nvim'
alias vdf='nvim -d'  # diff mode
alias vr='nvim -R'  # readonly
alias vs='nvim -S'  # session

# tmux
alias t='tmux'
alias tn='tmux new -s'
alias tk='tmux kill-session -t'
alias tt='tmux a -t'
alias tl='tmux ls'
alias tks='tmux kill-server'
alias tr='tmux rename-session -t'
alias tw='tmux rename-window'
alias ts='tmux switch -t'

# Remote development
alias mh='mosh home -- tmux new-session -A -s dev'
alias mn='mosh home -- tmux new-session -s'
alias ml='ssh home tmux list-sessions'
alias mt='mosh home -- tmux attach-session -t'

_ubuntu_desktop() {
  local rdp_password
  rdp_password="$(security find-generic-password -a 'iv@home' -s 'GNOME RDP home' -w)" || return 1

  print -r -- "$rdp_password" | /opt/homebrew/bin/sdl-freerdp \
    /v:iv-G5-5090.tail4b3505.ts.net \
    /u:iv \
    /from-stdin:force \
    /cert:tofu \
    /network:auto \
    /size:1600x900 \
    +smart-sizing \
    +clipboard
  local rdp_status=$pipestatus[2]

  unset rdp_password
  return "$rdp_status"
}
alias ubuntu-desktop='_ubuntu_desktop'
alias urdp='_ubuntu_desktop'

# Python virtual environment
alias va='source .venv/bin/activate'
alias vd='deactivate'
alias vc='python3 -m venv .venv'

# Julia
alias j='julia'

# Singularity
alias sec='singularity exec --nv Singularity.sif'
alias sb='singularity build --fakeroot Singularity.def Singularity.sif'

# AtCoder
alias ac='(){acc new abc$1 -c all}'
alias at='(){oj t -c "python3 ./$1/main.py" -d ./$1/tests/}'
alias as='(){cd $1;acc s ./main.py -- --guess-python-interpreter pypy -w 0 -y;cd -}'

# AI Tools (dangerous mode)
alias claudec='claude --dangerously-skip-permissions'
alias codexc='codex -a never -s danger-full-access'
alias dcode='dsh --profile dsh-tui'

# lazygit
alias lg='lazygit'

# System diagnosis
alias freeze='~/.dotfiles/scripts/freeze-diagnosis.sh'
alias freeze-monitor='~/.dotfiles/scripts/freeze-diagnosis.sh --monitor'
alias freeze-review='~/.dotfiles/scripts/freeze-diagnosis.sh --review'
