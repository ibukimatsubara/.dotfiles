#!/usr/bin/env bash
#
# tmo.tmux - tmux plugin entry point
# Adds tmo to PATH and configures tmux-resurrect integration
#

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Add bin directory to PATH for tmux environment
tmux set-environment -g PATH "${CURRENT_DIR}/bin:$PATH"

# Configure tmux-resurrect to restore tmo sessions
# Users should add this to their tmux.conf:
#   set -g @resurrect-processes 'tmo'
