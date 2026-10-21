#!/usr/bin/env bash
# Claude Code statusLine — mirrors ~/.dotfiles/theme/simple prompt

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd')
model=$(echo "$input" | jq -r '.model.display_name')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Share plan rate limits with the SketchyBar claude_usage item.
rate_limits=$(echo "$input" | jq -c '.rate_limits // empty')
if [ -n "$rate_limits" ]; then
  snapshot_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-code"
  snapshot_file="$snapshot_dir/rate-limits.json"
  previous=$(jq -c '.rate_limits // empty' "$snapshot_file" 2>/dev/null)
  if mkdir -p "$snapshot_dir" && snapshot_tmp=$(mktemp "$snapshot_dir/.rate-limits.XXXXXX"); then
    if jq -n --argjson rate_limits "$rate_limits" '{captured_at: (now | floor), rate_limits: $rate_limits}' >"$snapshot_tmp" &&
      mv "$snapshot_tmp" "$snapshot_file"; then
      if [ "$rate_limits" != "$previous" ] && command -v sketchybar >/dev/null 2>&1; then
        sketchybar --trigger claude_usage_update >/dev/null 2>&1 &
      fi
    else
      rm -f "$snapshot_tmp"
    fi
  fi
fi

# Colors (ANSI — terminal will dim these)
cyan='\033[36;1m'
magenta='\033[35;1m'
reset='\033[0m'
bright_cyan='\033[96m'
bright_magenta='\033[95m'
bright_blue='\033[94m'

sep=" - "

# Current directory — basename only
display_cwd=$(basename "$cwd")

# Git segment: worktree name if linked worktree, branch otherwise
git_label=""
if git -C "$cwd" rev-parse --git-dir &>/dev/null; then
  git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
  git_common_dir=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)
  if [ "$git_dir" != "$git_common_dir" ]; then
    # Linked worktree: git-dir is <main>/.git/worktrees/<name>
    git_label=$(basename "$git_dir")
  else
    git_label=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
  fi
fi

# Node env detection
node_env=""
if [ -f "$cwd/package.json" ]; then
  node_ver=$(node -v 2>/dev/null | sed 's/v//')
  if [ -n "$node_ver" ]; then
    node_env="⬢${node_ver}"
  fi
fi

# Build the line
line=""
printf "${bright_blue}%s${reset}" "$display_cwd"

if [ -n "$node_env" ]; then
  printf "${magenta}%s${reset}${bright_blue}%s${reset}" "$sep" "$node_env"
fi

if [ -n "$git_label" ] && [ "$git_label" != "$display_cwd" ]; then
  printf "${magenta}%s${reset}${bright_blue}%s${reset}" "$sep" "$git_label"
fi

# Model + context usage
printf "${magenta}%s${reset}${bright_blue}%s${reset}" "$sep" "$model"

if [ -n "$used" ]; then
  printf "${magenta}%s${reset}${bright_blue}ctx:%.0f%%${reset}" "$sep" "$used"
fi

echo ""
