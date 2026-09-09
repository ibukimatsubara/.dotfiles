#!/usr/bin/env bash

set -euo pipefail

if (($# == 0)); then
    echo "usage: svu-run command [args...]" >&2
    exit 2
fi

lock_dir="/run/svu-auto-suspend/locks"
lock="$lock_dir/$$"

if [[ ! -d "$lock_dir" ]]; then
    echo "svu-run: auto-suspend lock directory is unavailable" >&2
    exit 1
fi

: > "$lock"
cleanup() {
    rm -f "$lock"
}
trap cleanup EXIT HUP INT TERM

"$@"
