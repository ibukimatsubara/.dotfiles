#!/usr/bin/env bash

set -euo pipefail

config_file="${SVU_POWER_CONFIG:-$HOME/.config/svu-power/config}"
if [[ -f "$config_file" ]]; then
    # shellcheck source=/dev/null
    source "$config_file"
fi

worker_host="${SVU_SSH_HOST:-svu}"
coordinator_host="${SVU_COORDINATOR_HOST:-svm}"
wait_seconds="${SVU_WAKE_WAIT_SECONDS:-90}"
poll_seconds=3

if ssh -o BatchMode=yes -o ConnectTimeout=2 "$worker_host" true 2>/dev/null; then
    exec ssh "$worker_host" "$@"
fi

echo "SVU is offline; requesting wake through SVM..." >&2
ssh -o BatchMode=yes "$coordinator_host" '$HOME/.local/bin/wake-svu'

attempts=$((wait_seconds / poll_seconds))
if ((attempts < 1)); then
    attempts=1
fi

for ((attempt = 1; attempt <= attempts; attempt++)); do
    if ssh -o BatchMode=yes -o ConnectTimeout=2 "$worker_host" true 2>/dev/null; then
        exec ssh "$worker_host" "$@"
    fi
    sleep "$poll_seconds"
done

echo "ssh-svu: SVU did not become reachable within ${wait_seconds} seconds" >&2
exit 1
