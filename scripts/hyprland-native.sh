#!/usr/bin/env bash
# Native shell surfaces must not block while probing the Xwayland display.
set -euo pipefail
export GDK_BACKEND=wayland
exec env -u DISPLAY -u XAUTHORITY "$@"
