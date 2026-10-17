#!/usr/bin/env bash
# Pull the canonical Ubuntu library into a local folder for offline playback.
set -euo pipefail
umask 077
export PATH="${PATH:-/usr/bin:/bin}:/opt/homebrew/bin:/usr/local/bin"

mode="${1:-}"
case "$mode" in
    ''|--scheduled|--dry-run|--check-config|--apply-config) ;;
    *) echo "Usage: $0 [--dry-run | --scheduled | --check-config | --apply-config]" >&2; exit 1 ;;
esac
if [ "$#" -gt 1 ]; then
    echo "Pass only one mode at a time." >&2
    exit 1
fi

repo_dir="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().parents[1])' "${BASH_SOURCE[0]}")"
if [ "$mode" = --apply-config ]; then
    exec python3 "$repo_dir/scripts/music-player-sync.py" apply
fi

config_file="${XDG_CONFIG_HOME:-$HOME/.config}/music-sync/config"
if [ ! -f "$config_file" ]; then
    echo "Missing $config_file. Run scripts/setup-music-sync.sh --setup first." >&2
    exit 1
fi

MUSIC_SYNC_HOST=''
MUSIC_SYNC_REMOTE_DIR=''
MUSIC_SYNC_LOCAL_DIR="$HOME/Music/Shared"
MUSIC_SYNC_CLIAMP=0
MUSIC_SYNC_REMOTE_CLIAMP_DIR='.config/cliamp'
# This is a local, user-owned Bash configuration, never downloaded from Ubuntu.
source "$config_file"
if [[ "$MUSIC_SYNC_CLIAMP" != 0 && "$MUSIC_SYNC_CLIAMP" != 1 ]]; then
    echo "MUSIC_SYNC_CLIAMP must be 0 or 1." >&2
    exit 1
fi
host_pattern='^([a-zA-Z0-9_][a-zA-Z0-9_.-]*@)?[a-zA-Z0-9_][a-zA-Z0-9_.-]*$'
if [[ ! "$MUSIC_SYNC_HOST" =~ $host_pattern ]]; then
    echo "Set MUSIC_SYNC_HOST to an SSH alias or user@hostname in $config_file." >&2
    exit 1
fi
remote_dir="$MUSIC_SYNC_REMOTE_DIR"
while [[ "$remote_dir" = */ ]]; do remote_dir="${remote_dir%/}"; done
remote_dir="${remote_dir#\~/}"
case "$remote_dir" in
    ''|/|.|..|'~'|:*|../*|*/../*|*/..|*/.|*[$'\n\r']*|*\**|*\?*|*\[*|*\]*)
        echo "Set MUSIC_SYNC_REMOTE_DIR to one dedicated library directory, without wildcards." >&2
        exit 1 ;;
esac
local_dir="$MUSIC_SYNC_LOCAL_DIR"
while [[ "$local_dir" = */ ]]; do local_dir="${local_dir%/}"; done
case "$local_dir" in
    '~/'*) local_dir="$HOME/${local_dir#\~/}" ;;
esac
if [[ "$local_dir" != /* || "$local_dir" = "$HOME" || "$local_dir" = / ||
      -z "$local_dir" || "$local_dir" = */.. || "$local_dir" = */../* ||
      "$local_dir" = */. || "$local_dir" = */./* ||
      "$local_dir" = *$'\n'* || "$local_dir" = *$'\r'* ]]; then
    echo "MUSIC_SYNC_LOCAL_DIR must be an absolute path to a dedicated library directory." >&2
    exit 1
fi
if [ "$mode" = --check-config ]; then
    echo "Music sync configuration is valid."
    exit 0
fi

# -s protects spaces and shell characters in remote paths; both ends need rsync 3+.
rsync_bin=''
for candidate in "$(command -v rsync || true)" /opt/homebrew/bin/rsync /usr/local/bin/rsync; do
    if [ -x "$candidate" ] && "$candidate" -s --version >/dev/null 2>&1; then
        rsync_bin="$candidate"
        break
    fi
done
if [ -z "$rsync_bin" ]; then
    echo "rsync 3+ is required. Run ./install.sh, or brew install rsync on macOS." >&2
    exit 1
fi

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/music-sync"
mkdir -p "$state_dir"
# Keep an OS lock open across the shell's lifetime. It is released even after a
# crash, and prevents manual pulls from overlapping the daily LaunchAgent.
if [ "${DOTFILES_MUSIC_SYNC_LOCKED:-}" != "$state_dir" ]; then
    exec python3 - "$state_dir" "${BASH_SOURCE[0]}" "$@" <<'PY'
import fcntl
import os
import sys

state, script, *args = sys.argv[1:]
lock = open(os.path.join(state, 'sync.lock'), 'a')
try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    print('Another music sync is running; skipping this invocation.')
    sys.exit(0)
os.set_inheritable(lock.fileno(), True)
os.environ['DOTFILES_MUSIC_SYNC_LOCKED'] = state
os.execv('/bin/bash', ['/bin/bash', script, *args])
PY
fi
log_file="$state_dir/sync.log"
log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$log_file"; }

# Cache success per local calendar day and source/destination configuration.
today="$(date +%F)"
signature="$(printf '%s\n' v2 "$MUSIC_SYNC_HOST" "$remote_dir" "$local_dir" "$MUSIC_SYNC_CLIAMP" "$MUSIC_SYNC_REMOTE_CLIAMP_DIR" "${CLIAMP_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/cliamp}" | cksum)"
stamp="$today $signature"
if [ "$mode" = --scheduled ] && [ -f "$state_dir/last-success" ] &&
   [ "$(cat "$state_dir/last-success")" = "$stamp" ]; then
    log "Already synchronized today; skipping."
    exit 0
fi

options=(--recursive --times -s --itemize-changes --timeout=60
         "--partial-dir=$state_dir/partial" --exclude=.DS_Store --exclude=.rsync-partial/)
if [ "$mode" = --dry-run ]; then
    options+=(--dry-run)
fi
# BatchMode prevents scheduled password prompts. Keep normal SSH host-key checks.
transport='ssh -oBatchMode=yes -oConnectTimeout=10 -oServerAliveInterval=15 -oServerAliveCountMax=2'
mkdir -p "$local_dir"
log "Pulling $MUSIC_SYNC_HOST:$remote_dir/ into $local_dir/ ($mode)"
# No --delete, --inplace, --remove-source-files, or symlink traversal.
if "$rsync_bin" "${options[@]}" --rsh "$transport" -- \
        "$MUSIC_SYNC_HOST:$remote_dir/" "$local_dir/" 2>&1 | tee -a "$log_file"; then
    if [ "$mode" = --dry-run ]; then
        log "Preview complete; audio files and daily success state were not changed."
        exit 0
    fi
else
    status=$?
    log "Sync failed (exit $status); no files were deleted. Retry with music-sync."
    exit "$status"
fi

if [ "$MUSIC_SYNC_CLIAMP" = 1 ]; then
    log "Pulling cliamp playlists and podcast subscriptions."
    if ! python3 "$repo_dir/scripts/music-player-sync.py" pull --host "$MUSIC_SYNC_HOST" \
            --remote-config "$MUSIC_SYNC_REMOTE_CLIAMP_DIR" --remote-music "$remote_dir" \
            --local-music "$local_dir" 2>&1 | tee -a "$log_file"; then
        log "Player lists could not be synchronized; retry with music-sync."
        exit 1
    fi
fi

if command -v rmpc >/dev/null 2>&1; then
    if ! rmpc --address "$HOME/.local/state/mpd/socket" update >> "$log_file" 2>&1; then
        log "Files copied, but MPD could not refresh. Start MPD and run music-sync again."
        exit 1
    fi
else
    log "Files copied; install rmpc and run rmpc update to refresh the player."
fi

temporary="$(mktemp "$state_dir/last-success.XXXXXX")"
printf '%s %s\n' "$(date +%F)" "$signature" > "$temporary"
mv "$temporary" "$state_dir/last-success"
log "Sync complete. Local files remain available offline."
