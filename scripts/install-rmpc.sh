#!/usr/bin/env bash
# The official static Linux release works across supported Ubuntu versions.
set -euo pipefail

if command -v rmpc >/dev/null 2>&1; then
    printf 'rmpc already installed: %s\n' "$(command -v rmpc)"
    exit 0
fi

version=0.11.0
case "$(uname -m)" in
    x86_64|amd64)
        target=x86_64-unknown-linux-musl
        checksum=9cef6597d14ae58336ab465056da9e313d3b3bb3986c67691ee6ae13b7bf5a74
        ;;
    aarch64|arm64)
        target=aarch64-unknown-linux-musl
        checksum=ed5eef4a12cb1a32f05dd9d2116f0e291c6281b4acb9db16714442fdf004b21f
        ;;
    *) printf 'Unsupported architecture for rmpc: %s\n' "$(uname -m)" >&2; exit 1 ;;
esac

temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
archive="$temporary/rmpc.tar.gz"
url="https://github.com/mierak/rmpc/releases/download/v$version/rmpc-v$version-$target.tar.gz"
curl --fail --location --retry 2 --connect-timeout 15 --max-time 120 \
    "$url" --output "$archive"
printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check --status
tar -xzf "$archive" -C "$temporary"
binary="$temporary/rmpc"
[ -f "$binary" ] || { printf 'rmpc release has no binary\n' >&2; exit 1; }
mkdir -p "$HOME/.local/bin"
install -m 755 "$binary" "$HOME/.local/bin/rmpc"
printf 'Installed rmpc %s in ~/.local/bin.\n' "$version"
