#!/usr/bin/env bash

set -euo pipefail

state_dir="$HOME/.cache/ghostty-break"
state_file="$state_dir/break_state.glsl"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/break-timer-recovery-test.XXXXXX")"
backup_dir="$test_root/original-state"
test_passed=0

cleanup() {
    if [ "$test_passed" -ne 1 ] && [ -d "$backup_dir" ]; then
        if [ -e "$state_dir" ]; then
            mv "$state_dir" "$test_root/failed-state"
        fi
        mv "$backup_dir" "$state_dir"
    fi
    rm -rf "$test_root"
}
trap cleanup EXIT HUP INT TERM

if ! command -v hs >/dev/null 2>&1; then
    printf 'FAIL: Hammerspoon CLI is unavailable\n' >&2
    exit 1
fi

if [ "$(hs -c 'return type(breaktimer.refreshVisual)' 2>/dev/null)" != 'function' ]; then
    printf 'FAIL: breaktimer.refreshVisual is unavailable\n' >&2
    exit 1
fi

if [ -d "$state_dir" ]; then
    mv "$state_dir" "$backup_dir"
fi

if [ "$(hs -c 'return tostring(breaktimer.refreshVisual())' 2>/dev/null)" != 'true' ]; then
    printf 'FAIL: visual refresh reported failure\n' >&2
    exit 1
fi

attempts=0
while [ ! -s "$state_file" ] && [ "$attempts" -lt 20 ]; do
    sleep 0.1
    attempts=$((attempts + 1))
done

if [ ! -s "$state_file" ]; then
    printf 'FAIL: missing shader state was not regenerated\n' >&2
    exit 1
fi

if rg -q '\{\{(?:MODE|PROGRESS)\}\}' "$state_file"; then
    printf 'FAIL: regenerated shader still contains template placeholders\n' >&2
    exit 1
fi

test_passed=1
printf 'PASS: missing shader state is regenerated\n'
