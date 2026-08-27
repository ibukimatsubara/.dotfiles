#!/bin/bash

set -euo pipefail

readonly CONFIG_FILE="${OPEN_LOCAL_CONFIG:-$HOME/.config/open-local/config}"

usage() {
    echo "Usage: open-local <file>" >&2
}

find_tailscale_cli() {
    if command -v tailscale >/dev/null 2>&1; then
        command -v tailscale
    elif [ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
        printf '%s\n' /Applications/Tailscale.app/Contents/MacOS/Tailscale
    else
        echo "open-local: Tailscale CLI not found" >&2
        return 1
    fi
}

if [ "$#" -ne 1 ]; then
    usage
    exit 2
fi

source_file="$1"
if [ ! -f "$source_file" ]; then
    echo "open-local: regular file not found: $source_file" >&2
    exit 2
fi

taildrop_target="${TAILDROP_TARGET:-}"
if [ -z "$taildrop_target" ] && [ -f "$CONFIG_FILE" ]; then
    taildrop_target="$(sed -n 's/^TAILDROP_TARGET=//p' "$CONFIG_FILE" | head -n 1)"
fi

case "$taildrop_target" in
    ""|*[!A-Za-z0-9._-]*)
        echo "open-local: set a valid TAILDROP_TARGET in $CONFIG_FILE" >&2
        exit 2
        ;;
esac

base_name="$(basename "$source_file")"
case "$base_name" in
    *$'\n'*|*$'\r'*)
        echo "open-local: filenames containing newlines are not supported" >&2
        exit 2
        ;;
esac

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
transfer_name="svm-open--${timestamp}--${base_name}"
tailscale_cli="$(find_tailscale_cli)"

echo "Sending $base_name to $taildrop_target..."
TAILSCALE_BE_CLI=1 "$tailscale_cli" file cp \
    --name="$transfer_name" \
    - \
    "${taildrop_target}:" < "$source_file"
echo "Sent. The local Mac will save and open the file."
