#!/usr/bin/env bash
set -euo pipefail

# Background schedulers have a minimal PATH. Reuse installed tools without loading shell startup files.
export PATH="$HOME/.local/bin:$HOME/google-cloud-sdk/bin:/opt/homebrew/bin:/usr/local/bin:/opt/homebrew/share/google-cloud-sdk/bin:/usr/local/share/google-cloud-sdk/bin:/usr/bin:/bin:$PATH"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/mibuki-metrics"

[[ -f "$config_dir/enabled" || "${1:-}" == --validate-config ]] || exit 0
# This private file is shared with ~/.zshrc.local; credentials never enter the plist.
if [[ -f "$config_dir/secrets.env" ]]; then
    source "$config_dir/secrets.env"
fi
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$repo_dir/scripts/mibuki-metrics.py" "$@"
