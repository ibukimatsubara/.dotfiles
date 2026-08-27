#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
worker="$script_dir/tmux-pane-summaries.sh"
fixture="$script_dir/test-fixtures/tmux-pane-summaries/fake-command.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/tmux-pane-summary-test.XXXXXX")"

cleanup() {
    rm -rf "$test_root"
}
trap cleanup EXIT HUP INT TERM

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

new_scenario() {
    scenario="$1"
    scenario_dir="$test_root/$scenario"
    fake_bin="$scenario_dir/bin"
    test_home="$scenario_dir/home"
    test_tmp="$scenario_dir/tmp"
    state_file="$scenario_dir/tmux-state"
    child_pid_file="$scenario_dir/child-pid"
    mkdir -p "$fake_bin" "$test_home" "$test_tmp"
    : > "$state_file"
    ln -s "$fixture" "$fake_bin/tmux"
    ln -s "$fixture" "$fake_bin/codex"
}

run_worker() {
    mode="$1"
    timeout_seconds="${2:-2}"
    max_rss_mb="${3:-256}"

    HOME="$test_home" \
    TMPDIR="$test_tmp" \
    TMUX_PANE_SUMMARY_PATH_PREFIX="$fake_bin" \
    FAKE_TMUX_STATE="$state_file" \
    FAKE_CODEX_MODE="$mode" \
    FAKE_CHILD_PID_FILE="$child_pid_file" \
    FAKE_TIMEOUT_SECONDS="$timeout_seconds" \
    FAKE_MAX_RSS_MB="$max_rss_mb" \
        "$worker" --force
}

run_worker_dry() {
    HOME="$test_home" \
    TMPDIR="$test_tmp" \
    TMUX_PANE_SUMMARY_PATH_PREFIX="$fake_bin" \
    FAKE_TMUX_STATE="$state_file" \
    FAKE_PANE_COUNT="${FAKE_PANE_COUNT:-1}" \
    FAKE_MAX_PANES="${FAKE_MAX_PANES:-2}" \
        "$worker" --force --dry-run
}

assert_process_stopped() {
    pid="$1"
    attempts=0
    while [ "$attempts" -lt 20 ]; do
        state="$(ps -o stat= -p "$pid" 2>/dev/null | tr -d ' ' || true)"
        case "$state" in
            ''|Z*) return 0 ;;
        esac
        sleep 0.1
        attempts=$((attempts + 1))
    done
    fail "orphan process $pid is still running"
}

new_scenario work_only
run_worker success
summary="$(sed -n 's/^summary=//p' "$state_file" | tail -n 1)"
[ -n "$summary" ] || fail 'success result was not stored'
[ "$(sed -n 's/^model=//p' "$state_file" | tail -n 1)" = 'gpt-5.6-luna' ] \
    || fail 'worker did not select gpt-5.6-luna'
if printf '%s\n' "$summary" | rg -q '待機|完了|済み|idle'; then
    fail "summary contains status wording: $summary"
fi
printf 'PASS: work-only summary\n'

new_scenario utf8_locale
LANG=C LC_ALL=C run_worker success
if ! rg -q '^capture-locale=en_US.UTF-8$' "$state_file"; then
    fail 'worker did not force a UTF-8 locale for launchd'
fi
printf 'PASS: launchd uses a UTF-8 capture locale\n'

new_scenario fair_rotation
first_batch="$(FAKE_PANE_COUNT=4 FAKE_MAX_PANES=2 run_worker_dry)"
second_batch="$(FAKE_PANE_COUNT=4 FAKE_MAX_PANES=2 run_worker_dry)"
printf '%s\n' "$first_batch" | rg -q '^=== PANE %1 ===$' || fail 'first rotation batch omitted pane %1'
printf '%s\n' "$first_batch" | rg -q '^=== PANE %2 ===$' || fail 'first rotation batch omitted pane %2'
if printf '%s\n' "$first_batch" | rg -q '^=== PANE %3 ===$'; then
    fail 'first rotation batch exceeded the pane limit'
fi
printf '%s\n' "$second_batch" | rg -q '^=== PANE %3 ===$' || fail 'second rotation batch omitted pane %3'
printf '%s\n' "$second_batch" | rg -q '^=== PANE %4 ===$' || fail 'second rotation batch omitted pane %4'
printf 'PASS: changed panes rotate fairly across runs\n'

new_scenario malformed
if run_worker malformed; then
    fail 'malformed JSON returned success'
fi
if rg -q '^summary=' "$state_file"; then
    fail 'malformed JSON replaced the previous summary'
fi
printf 'PASS: malformed output is rejected\n'

new_scenario oversized
if run_worker oversized; then
    fail 'oversized output returned success'
fi
if rg -q '^summary=' "$state_file"; then
    fail 'oversized output replaced the previous summary'
fi
printf 'PASS: oversized output is rejected\n'

new_scenario connection_error
if run_worker connection-error; then
    fail 'connection error returned success'
fi
if rg -q '^summary=' "$state_file"; then
    fail 'connection error replaced the previous summary'
fi
printf 'PASS: connection error is non-destructive\n'

new_scenario timeout
started_at="$(date +%s)"
if run_worker hang-child 2 256; then
    fail 'timeout returned success'
fi
elapsed=$(( $(date +%s) - started_at ))
[ "$elapsed" -lt 10 ] || fail "timeout took ${elapsed}s"
child_pid="$(cat "$child_pid_file")"
assert_process_stopped "$child_pid"
printf 'PASS: timeout kills the process group\n'

new_scenario worker_sigkill
HOME="$test_home" \
TMPDIR="$test_tmp" \
TMUX_PANE_SUMMARY_PATH_PREFIX="$fake_bin" \
FAKE_TMUX_STATE="$state_file" \
FAKE_CODEX_MODE='hang-child' \
FAKE_CHILD_PID_FILE="$child_pid_file" \
FAKE_TIMEOUT_SECONDS='30' \
FAKE_MAX_RSS_MB='256' \
    "$worker" --force &
worker_pid=$!
attempts=0
while [ ! -s "$child_pid_file" ] && [ "$attempts" -lt 30 ]; do
    sleep 0.1
    attempts=$((attempts + 1))
done
[ -s "$child_pid_file" ] || fail 'SIGKILL fixture did not start'
/bin/kill -KILL "$worker_pid"
wait "$worker_pid" 2>/dev/null || true
child_pid="$(cat "$child_pid_file")"
assert_process_stopped "$child_pid"
printf 'PASS: worker SIGKILL does not orphan Codex children\n'

new_scenario memory
started_at="$(date +%s)"
if run_worker memory 10 16; then
    fail 'memory limit returned success'
fi
elapsed=$(( $(date +%s) - started_at ))
[ "$elapsed" -lt 10 ] || fail "memory watchdog took ${elapsed}s"
child_pid="$(cat "$child_pid_file")"
assert_process_stopped "$child_pid"
printf 'PASS: memory watchdog kills the process group\n'

new_scenario stale_lock
mkdir -p "$test_tmp/com.local.tmux-pane-summaries.lock"
printf '%s\n' '999999' > "$test_tmp/com.local.tmux-pane-summaries.lock/pid"
run_worker success
if ! rg -q '^summary=' "$state_file"; then
    fail 'stale lock prevented the worker from running'
fi
printf 'PASS: stale lock is recovered\n'
