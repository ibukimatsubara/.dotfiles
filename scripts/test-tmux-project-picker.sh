#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
picker="$repo_dir/scripts/tmux-project-picker.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/tmux-project-picker-test.XXXXXX")"
test_home="$test_root/home"
current="$test_home/current"
saved="$test_home/saved project"
recent="$test_home/recent"
history_file="$test_home/.cache/tmux/project-history"
paths_file="$test_home/.config/tmux/project-paths"

cleanup() {
    rm -rf "$test_root"
}
trap cleanup EXIT HUP INT TERM

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

mkdir -p "$current" "$saved" "$recent"
current=$(cd "$current" && pwd -P)
saved=$(cd "$saved" && pwd -P)
recent=$(cd "$recent" && pwd -P)

picker_env=(
    HOME="$test_home"
    TMUX_PROJECT_HISTORY_FILE="$history_file"
    TMUX_PROJECT_PATHS_FILE="$paths_file"
    TMUX_PROJECT_SKIP_TMUX=1
    TMUX_PROJECT_SKIP_ZOXIDE=1
)

env "${picker_env[@]}" "$picker" --add "$saved"
env "${picker_env[@]}" "$picker" --record "$recent"
env "${picker_env[@]}" "$picker" --record "$saved"

rendered=$(env "${picker_env[@]}" "$picker" --list "$current")
first_path=$(printf '%s\n' "$rendered" | awk -F '\t' 'NR == 1 { print $3 }')
[ "$first_path" = "$current" ] || fail 'current path is not ranked first'

[ "$(printf '%s\n' "$rendered" | awk -F '\t' -v path="$saved" '$3 == path { count++ } END { print count + 0 }')" -eq 1 ] \
    || fail 'saved/history duplicate was not removed'
printf '%s\n' "$rendered" | awk -F '\t' -v path="$saved" '$1 == "★ saved " && $3 == path { found = 1 } END { exit !found }' \
    || fail 'saved path is missing from the list'
printf '%s\n' "$rendered" | awk -F '\t' -v path="$recent" '$1 == "↺ recent" && $3 == path { found = 1 } END { exit !found }' \
    || fail 'recent path is missing from the list'

[ "$(stat -f '%Lp' "$history_file")" = '600' ] || fail 'history permissions are not 0600'
[ "$(stat -f '%Lp' "$paths_file")" = '600' ] || fail 'saved path permissions are not 0600'

if env "${picker_env[@]}" "$picker" --add "$test_home/missing"; then
    fail 'missing directory was accepted'
fi

rg -q 'User0 display-popup.*tmux-project-picker\.sh shell' "$repo_dir/tmux/tmux.conf" \
    || fail 'Cmd+T is not bound to the shell picker'
rg -q 'User2 display-popup.*tmux-project-picker\.sh codex' "$repo_dir/tmux/tmux.conf" \
    || fail 'Cmd+R is not bound to the Codex picker'

printf 'PASS: project picker ranks, deduplicates, stores, and validates paths\n'
