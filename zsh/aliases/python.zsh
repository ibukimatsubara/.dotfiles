# Python package managers

# Poetry aliases
alias po='poetry'
alias poi='poetry install'
alias poa='poetry add'
alias por='poetry remove'
alias pou='poetry update'
alias pos='poetry shell'
alias pob='poetry build'
alias pop='poetry publish'
alias pol='poetry lock'
alias poe='poetry env'
alias poei='poetry env info'

# uv aliases - main Python workflow
alias uv='uv'
alias uvr='uv run'
alias uvs='uv sync'
alias uva='uv add'
alias uvad='uv add --dev'  
alias uvrm='uv remove'
alias uvl='uv lock'
alias uvi='uv init'
alias uvv='uv venv'

# uv pip compatibility
alias uvp='uv pip'
alias uvpi='uv pip install'
alias uvpir='uv pip install -r requirements.txt'
alias uvps='uv pip sync requirements.txt'
alias uvpc='uv pip compile'

# uv tool management
alias uvt='uv tool'
alias uvti='uv tool install'
alias uvtu='uv tool upgrade'
alias uvtr='uv tool run'

# Python aliases (補足)
alias p='python'
alias p3='python3'
alias pi='pip install'
alias pir='pip install -r requirements.txt'
alias pf='pip freeze'
alias pu='pip uninstall'