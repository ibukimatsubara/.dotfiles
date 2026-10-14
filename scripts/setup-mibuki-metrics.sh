#!/usr/bin/env bash
set -euo pipefail
umask 077

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/mibuki-metrics"
label="com.local.mibuki-metrics"
launch_agent="$HOME/Library/LaunchAgents/$label.plist"

case "${1:-}" in
    --disable)
        rm -f "$config_dir/enabled"
        if [[ "$OSTYPE" == darwin* ]]; then
            launchctl bootout "gui/$UID/$label" >/dev/null 2>&1 || true
            rm -f "$launch_agent"
        fi
        echo "Metrics disabled on this computer. Cached data and credentials were kept."
        exit 0
        ;;
    --enable) ;;
    *)
        echo "Usage: $0 --enable | --disable" >&2
        exit 1
        ;;
esac

[[ "$OSTYPE" == darwin* ]] || { echo "The metrics LaunchAgent supports macOS only." >&2; exit 1; }
mkdir -p "$config_dir"
chmod 700 "$config_dir"
if [[ ! -f "$config_dir/config.json" ]]; then
    cp "$repo_dir/scripts/mibuki-metrics.config.example.json" "$config_dir/config.json"
    echo "Created $config_dir/config.json. Fill in your service settings, then rerun --enable."
    exit 1
fi
bash "$repo_dir/scripts/mibuki-metrics.sh" --validate-config
chmod 600 "$config_dir/config.json"
mkdir -p "$HOME/Library/LaunchAgents"

# Render the portable template into this machine's LaunchAgent; do not use a login shell.
python3 - "$repo_dir" "$launch_agent" <<'PY'
import os
from pathlib import Path
import plistlib
import sys

repo_dir, target = map(Path, sys.argv[1:])
with (repo_dir / 'launchd/com.local.mibuki-metrics.plist').open('rb') as source:
    agent = plistlib.load(source)
agent['ProgramArguments'] = ['/bin/bash', str(repo_dir / 'scripts/mibuki-metrics.sh')]
agent['EnvironmentVariables'] = {key: os.environ[key] for key in
                               ('XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME') if os.environ.get(key)}
with target.open('wb') as output:
    plistlib.dump(agent, output)
PY

touch "$config_dir/enabled"
launchctl bootout "gui/$UID/$label" >/dev/null 2>&1 || true
launchctl enable "gui/$UID/$label"
if ! launchctl bootstrap "gui/$UID" "$launch_agent"; then
    rm -f "$config_dir/enabled"
    echo "Could not install the metrics LaunchAgent; metrics remain disabled." >&2
    exit 1
fi

echo "Metrics enabled on this computer. Updates run at login and every 15 minutes while awake."
echo "Successful metrics are fetched once per day; failed metrics retry on the next check."
echo "Cache: ${XDG_DATA_HOME:-$HOME/.local/share}/mibuki-metrics"
echo "Log: ${XDG_STATE_HOME:-$HOME/.local/state}/mibuki-metrics/refresh.log"
