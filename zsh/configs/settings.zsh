# Zsh core settings
setopt sharehistory
setopt auto_cd
setopt correct

# DSH: trust local sessions by default and skip per-command approval prompts.
# Override per invocation with DSH_PERMISSION_MODE=workspace-write when needed.
export DSH_PERMISSION_MODE=danger-full-access