#!/usr/bin/env bash

set -euo pipefail

IDLE_SECONDS="${IDLE_SECONDS:-3600}"
LOAD_THRESHOLD="${LOAD_THRESHOLD:-0.50}"
STATE_DIR="/run/svu-auto-suspend"
LOCK_DIR="$STATE_DIR/locks"
STATE_FILE="$STATE_DIR/state"

mkdir -p "$LOCK_DIR"

now=$(date +%s)
uptime_now=$(cut -d. -f1 /proc/uptime)
last_wall=$now
last_uptime=$uptime_now
last_active=$now

if [[ -r "$STATE_FILE" ]] && read -r saved_wall saved_uptime saved_active < "$STATE_FILE"; then
    if [[ "$saved_wall" =~ ^[0-9]+$ && "$saved_uptime" =~ ^[0-9]+$ && \
        "$saved_active" =~ ^[0-9]+$ ]]; then
        last_wall=$saved_wall
        last_uptime=$saved_uptime
        last_active=$saved_active
    fi
fi

# A reboot or a suspend/resume gap starts a fresh idle window.
wall_delta=$((now - last_wall))
uptime_delta=$((uptime_now - last_uptime))
if ((uptime_delta < 0 || wall_delta - uptime_delta > 30)); then
    last_active=$now
fi

busy_reason=""

if [[ -n "$(loginctl list-sessions --no-legend 2>/dev/null)" ]]; then
    busy_reason="login-session"
elif [[ -n "$(ss -Htn state established '( sport = :22 )' 2>/dev/null)" ]]; then
    busy_reason="ssh"
fi

if [[ -z "$busy_reason" ]] && command -v nvidia-smi >/dev/null 2>&1; then
    gpu_processes=$(nvidia-smi --query-compute-apps=pid \
        --format=csv,noheader,nounits 2>/dev/null || true)
    if grep -Eq '^[[:space:]]*[0-9]+' <<< "$gpu_processes"; then
        busy_reason="gpu-process"
    fi
fi

if [[ -z "$busy_reason" ]]; then
    load_one=$(awk '{ print $1 }' /proc/loadavg)
    if awk -v load="$load_one" -v limit="$LOAD_THRESHOLD" \
        'BEGIN { exit !(load > limit) }'; then
        busy_reason="cpu-load"
    fi
fi

if [[ -z "$busy_reason" ]]; then
    shopt -s nullglob
    for lock in "$LOCK_DIR"/*; do
        pid=${lock##*/}
        if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
            busy_reason="protected-job"
            break
        fi
        rm -f "$lock"
    done
    shopt -u nullglob
fi

if [[ -n "$busy_reason" ]]; then
    last_active=$now
fi

tmp_state="$STATE_FILE.tmp"
printf '%s %s %s\n' "$now" "$uptime_now" "$last_active" > "$tmp_state"
mv "$tmp_state" "$STATE_FILE"

idle_for=$((now - last_active))
if [[ "${1:-}" == "--status" ]]; then
    printf 'busy=%s idle_for=%ss idle_limit=%ss load_threshold=%s\n' \
        "${busy_reason:-no}" "$idle_for" "$IDLE_SECONDS" "$LOAD_THRESHOLD"
    exit 0
fi

if [[ -z "$busy_reason" ]] && ((idle_for >= IDLE_SECONDS)); then
    logger -t svu-auto-suspend "Suspending after ${idle_for}s idle"
    systemctl suspend
fi
