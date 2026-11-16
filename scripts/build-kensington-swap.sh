#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
    printf 'kensington_swap builds only on macOS.\n' >&2
    exit 1
fi
if [[ $# -gt 1 ]]; then
    printf 'usage: %s [output.so]\n' "$0" >&2
    exit 1
fi

clang="/usr/bin/clang"
hammerspoon_app="${HAMMERSPOON_APP:-/Applications/Hammerspoon.app}"
headers="${hammerspoon_app}/Contents/Frameworks/LuaSkin.framework/Versions/A/Headers"
root="$(cd "$(dirname "$0")/.." && pwd)"
source="${root}/hammerspoon/kensington_swap.c"
output="${1:-${HOME}/.hammerspoon/kensington_swap.so}"

if [[ ! -x "${clang}" ]]; then
    printf 'Apple clang not found at %s\n' "${clang}" >&2
    exit 1
fi
if [[ ! -f "${headers}/lua.h" ]]; then
    printf 'Hammerspoon Lua headers not found: %s\n' "${headers}/lua.h" >&2
    printf 'Set HAMMERSPOON_APP to the Hammerspoon.app that bundles LuaSkin.\n' >&2
    exit 1
fi
if [[ ! -f "${source}" ]]; then
    printf 'Missing source: %s\n' "${source}" >&2
    exit 1
fi

output_dir="$(dirname "${output}")"
if ! mkdir -p "${output_dir}"; then
    printf 'Cannot create output directory: %s\n' "${output_dir}" >&2
    exit 1
fi

if ! "${clang}" -Wall -Wextra -Werror \
    -I"${headers}" \
    -bundle -undefined dynamic_lookup \
    -framework CoreGraphics -framework IOKit -framework CoreFoundation \
    "${source}" -o "${output}"; then
    printf 'Failed to compile %s\n' "${source}" >&2
    exit 1
fi
printf 'Built %s\n' "${output}"
