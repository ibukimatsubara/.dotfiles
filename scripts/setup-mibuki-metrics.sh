#!/usr/bin/env bash
set -euo pipefail
umask 077

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/mibuki-metrics"
label="com.local.mibuki-metrics"
launch_agent="$HOME/Library/LaunchAgents/$label.plist"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

case "${1:-}" in
    --disable)
        rm -f "$config_dir/enabled"
        if [[ "$OSTYPE" == darwin* ]]; then
            launchctl bootout "gui/$UID/$label" >/dev/null 2>&1 || true
            rm -f "$launch_agent"
        elif [[ "$OSTYPE" == linux* ]]; then
            systemctl --user disable --now mibuki-metrics.timer >/dev/null 2>&1 || true
            systemctl --user stop mibuki-metrics.service >/dev/null 2>&1 || true
            rm -f "$unit_dir/mibuki-metrics.timer" "$unit_dir/mibuki-metrics.service"
            systemctl --user daemon-reload
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

case "$OSTYPE" in
    darwin*) ;;
    linux*) command -v systemctl >/dev/null || { echo "systemd user services are required." >&2; exit 1; } ;;
    *) echo "Supported platforms: macOS and Linux with systemd." >&2; exit 1 ;;
esac
mkdir -p "$config_dir"
chmod 700 "$config_dir"
if [[ ! -f "$config_dir/config.json" ]]; then
    cp "$repo_dir/scripts/mibuki-metrics.config.example.json" "$config_dir/config.json"
    echo "Created $config_dir/config.json. Fill in your service settings, then rerun --enable."
    exit 1
fi
bash "$repo_dir/scripts/mibuki-metrics.sh" --validate-config
chmod 600 "$config_dir/config.json"
if [[ "$OSTYPE" == linux* ]]; then
    mkdir -p "$unit_dir"
    python3 - "$repo_dir" "$unit_dir" <<'PYTHON'
import os
from pathlib import Path
import sys

repo, units = map(Path, sys.argv[1:])
# Quote systemd syntax, including specifier and ExecStart expansion.
def quote(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"').replace('%', '%%').replace('\n', '\\n').replace('\r', '\\r') + '"'

environment = {key: os.environ[key] for key in
               ('XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME') if os.environ.get(key)}
service = ['[Unit]', 'Description=Refresh Mibuki service metrics', '', '[Service]',
           'Type=oneshot', 'UMask=0077',
           'ExecStart=/bin/bash ' + quote(str(repo / 'scripts/mibuki-metrics.sh').replace('$', '$$'))]
service += ['Environment=' + quote(key + '=' + value) for key, value in environment.items()]
(units / 'mibuki-metrics.service').write_text('\n'.join(service) + '\n')
(units / 'mibuki-metrics.timer').write_text(
    '[Unit]\nDescription=Refresh Mibuki metrics daily\n\n'
    '[Timer]\nOnCalendar=daily\nPersistent=true\n\n'
    '[Install]\nWantedBy=timers.target\n')
PYTHON
    systemctl --user daemon-reload
    touch "$config_dir/enabled"
    if ! systemctl --user enable --now mibuki-metrics.timer; then
        rm -f "$config_dir/enabled"
        systemctl --user disable --now mibuki-metrics.timer >/dev/null 2>&1 || true
        echo "Could not start the metrics timer; metrics remain disabled." >&2
        exit 1
    fi
    echo "Metrics enabled. The systemd user timer updates once daily (missed runs resume at login)."
    exit 0
fi
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
