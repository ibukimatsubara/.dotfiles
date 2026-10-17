#!/usr/bin/env bash
set -euo pipefail
case "${1:-copy}" in
  copy)
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null; then
      exec wl-copy
    elif command -v pbcopy >/dev/null; then
      exec pbcopy
    else
      exec xclip -selection clipboard
    fi
    ;;
  paste)
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-paste >/dev/null; then
      exec wl-paste --no-newline
    elif command -v pbpaste >/dev/null; then
      exec pbpaste
    else
      exec xclip -selection clipboard -o
    fi
    ;;
  *) exit 2 ;;
esac
