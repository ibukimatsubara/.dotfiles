#!/bin/sh
set -eu

LABEL="com.local.enforceblocklist"
HOSTS_FILE="/etc/hosts"
BEGIN_MARKER="# === BLOCKLIST_START ==="
END_MARKER="# === BLOCKLIST_END ==="

tmp="$(mktemp /tmp/enforce-blocklist-off.XXXXXX)"
trap 'rm -f "$tmp"' EXIT

sudo launchctl disable "system/$LABEL" 2>/dev/null || true
sudo launchctl bootout "system/$LABEL" 2>/dev/null || true

sudo awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
  $0 == begin { skip = 1; next }
  $0 == end { skip = 0; next }
  skip != 1 { print }
' "$HOSTS_FILE" > "$tmp"

sudo install -m 0644 "$tmp" "$HOSTS_FILE"
sudo /usr/bin/dscacheutil -flushcache
sudo /usr/bin/killall -HUP mDNSResponder 2>/dev/null || true

echo "blocklist off"
