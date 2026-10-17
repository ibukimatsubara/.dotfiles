#!/usr/bin/env bash
# Install the command everywhere; opt in to the daily LaunchAgent on each Mac.
set -euo pipefail
umask 077
export PATH="${PATH:-/usr/bin:/bin}:/opt/homebrew/bin:/usr/local/bin"

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/music-sync"
label='com.local.music-sync'
launch_agent="$HOME/Library/LaunchAgents/$label.plist"
mode="${1:---setup}"
case "$mode" in
    --setup|--enable|--disable) ;;
    *) echo "Usage: $0 [--setup | --enable | --disable]" >&2; exit 1 ;;
esac

if [ "$mode" = --disable ]; then
    rm -f "$config_dir/enabled"
    if [ "$(uname -s)" = Darwin ]; then
        launchctl bootout "gui/$UID/$label" >/dev/null 2>&1 || true
        rm -f "$launch_agent"
    fi
    echo "Daily music sync disabled. Music, configuration, and sync history were kept."
    exit 0
fi

mkdir -p "$config_dir" "$HOME/.local/bin"
if [ ! -e "$config_dir/config" ]; then
    cp "$repo_dir/music-sync/config.example" "$config_dir/config"
    chmod 600 "$config_dir/config"
    echo "Created $config_dir/config. Set the Ubuntu SSH host and music directory."
fi
source "$repo_dir/platforms/common/lib.sh"
source "$repo_dir/platforms/common/setup.sh"
link_managed_path "$repo_dir/scripts/music-sync.sh" "$HOME/.local/bin/music-sync"
link_managed_path "$repo_dir/scripts/music-player.sh" "$HOME/.local/bin/music"

if [ "$mode" = --setup ] && [ ! -f "$config_dir/enabled" ]; then
    echo "Music sync command installed. Configure it, then run scripts/setup-music-sync.sh --enable on macOS."
    exit 0
fi
if [ "$(uname -s)" != Darwin ]; then
    echo "The daily music sync LaunchAgent supports macOS only." >&2
    exit 1
fi
bash "$repo_dir/scripts/music-sync.sh" --check-config
mkdir -p "$HOME/Library/LaunchAgents"

# Resolve paths with plistlib; launchd does not expand ~ or shell variables.
python3 - "$repo_dir" "$launch_agent" <<'PY'
import os
from pathlib import Path
import plistlib
import sys

repo, target = map(Path, sys.argv[1:])
with (repo / 'launchd/com.local.music-sync.plist').open('rb') as source:
    agent = plistlib.load(source)
agent['ProgramArguments'] = ['/bin/bash', str(repo / 'scripts/music-sync.sh'), '--scheduled']
for key in ('XDG_CONFIG_HOME', 'XDG_STATE_HOME', 'CLIAMP_CONFIG_DIR'):
    if os.environ.get(key):
        agent['EnvironmentVariables'][key] = os.environ[key]
state = Path(os.environ.get('XDG_STATE_HOME') or str(Path.home() / '.local/state')) / 'music-sync'
state.mkdir(parents=True, exist_ok=True)
agent['StandardOutPath'] = str(state / 'agent.log')
agent['StandardErrorPath'] = str(state / 'agent.log')
with target.open('wb') as output:
    plistlib.dump(agent, output)
PY

launchctl bootout "gui/$UID/$label" >/dev/null 2>&1 || true
if ! { launchctl enable "gui/$UID/$label" && launchctl bootstrap "gui/$UID" "$launch_agent"; }; then
    rm -f "$config_dir/enabled" "$launch_agent"
    echo "Could not register the music sync LaunchAgent; daily sync is disabled." >&2
    exit 1
fi
touch "$config_dir/enabled"
echo "Daily music sync enabled: 09:00 local time, plus login if not yet successful today."
echo "Log: ${XDG_STATE_HOME:-$HOME/.local/state}/music-sync/sync.log"
