#!/usr/bin/env bash
set -euo pipefail

version=1.11.1
if [ "$(uname -s)" != Linux ] || [ "$(uname -m)" != x86_64 ]; then
    printf 'Unsupported platform for wlr-draw %s: %s/%s. This installer supports only x86_64 Linux.\n' \
        "$version" "$(uname -s)" "$(uname -m)" >&2
    exit 1
fi
if [ -x "$HOME/.local/bin/wlr-draw" ] && [ "$("$HOME/.local/bin/wlr-draw" --version 2>/dev/null || true)" = "wlr-draw $version" ]; then
    printf 'wlr-draw %s already installed.\n' "$version"
    exit 0
fi

temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
archive="$temporary/wlr-utils.tar.xz"
curl --fail --location \
    "https://github.com/sjourdois/wlr-utils/releases/download/v$version/wlr-utils-x86_64-unknown-linux-gnu.tar.xz" \
    --output "$archive"
tar -xJf "$archive" -C "$temporary"
prefix="$temporary/wlr-utils-x86_64-unknown-linux-gnu"
license_dir="${XDG_DATA_HOME:-$HOME/.local/share}/licenses/wlr-draw"
mkdir -p "$HOME/.local/bin" "$license_dir"
install -m 755 "$prefix/wlr-draw" "$HOME/.local/bin/wlr-draw"
install -m 644 "$prefix/LICENSE-MIT" "$license_dir/LICENSE-MIT"
install -m 644 "$prefix/LICENSE-APACHE" "$license_dir/LICENSE-APACHE"
printf 'Installed wlr-draw %s in ~/.local/bin.\n' "$version"
