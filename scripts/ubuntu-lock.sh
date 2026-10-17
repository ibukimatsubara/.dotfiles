#!/usr/bin/env bash
set -euo pipefail
exec flock -n "${XDG_RUNTIME_DIR:?}/dotfiles-hyprlock.lock" hyprlock
