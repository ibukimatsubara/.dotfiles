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

# AI Tools (auto-accept mode)
alias claudec='claude --dangerously-skip-permissions'
alias codexc='codex --full-auto'

# lazygit
alias lg='lazygit'