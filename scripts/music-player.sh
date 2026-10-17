#!/usr/bin/env bash
# Apply downloaded shared lists offline before opening cliamp.
set -euo pipefail
export PATH="${PATH:-/usr/bin:/bin}:/opt/homebrew/bin:/usr/local/bin"
repo_dir="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().parents[1])' "${BASH_SOURCE[0]}")"
python3 "$repo_dir/scripts/music-player-sync.py" apply
if ! command -v cliamp >/dev/null 2>&1; then
    echo "cliamp is required. See docs/music.md for installation." >&2
    exit 1
fi
if [ "$#" -eq 0 ]; then
    exec cliamp --playlist Music
fi
exec cliamp "$@"
