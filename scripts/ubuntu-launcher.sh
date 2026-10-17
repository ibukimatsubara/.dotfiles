#!/usr/bin/env bash
set -euo pipefail
if command -v vicinae >/dev/null 2>&1; then
    exec vicinae toggle
fi
exec fuzzel
