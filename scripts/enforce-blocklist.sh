#!/bin/sh
set -eu

HOSTS_FILE="${ENFORCE_BLOCKLIST_HOSTS_FILE:-/etc/hosts}"
BACKUP_FILE="${ENFORCE_BLOCKLIST_BACKUP_FILE:-/etc/hosts.enforce-blocklist.bak}"
FLUSH_DNS="${ENFORCE_BLOCKLIST_FLUSH_DNS:-1}"

BEGIN_MARKER="# === BLOCKLIST_START ==="
END_MARKER="# === BLOCKLIST_END ==="

DOMAINS="
youtube.com
www.youtube.com
m.youtube.com
music.youtube.com
studio.youtube.com
youtu.be
www.youtu.be
youtube-nocookie.com
www.youtube-nocookie.com
x.com
www.x.com
twitter.com
www.twitter.com
mobile.twitter.com
api.twitter.com
t.co
twimg.com
www.twimg.com
pbs.twimg.com
video.twimg.com
abs.twimg.com
"

tmp="$(mktemp /tmp/enforce-blocklist.XXXXXX)"
trap 'rm -f "$tmp" "$tmp.block" "$tmp.next" "$tmp.stripped"' EXIT

{
  printf '%s\n' "$BEGIN_MARKER"
  printf '# managed by /usr/local/bin/enforce-blocklist.sh\n'
  for domain in $DOMAINS; do
    printf '0.0.0.0 %s\n' "$domain"
    printf '::1 %s\n' "$domain"
  done
  printf '%s\n' "$END_MARKER"
} > "$tmp.block"

awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
  $0 == begin { skip = 1; next }
  $0 == end { skip = 0; next }
  skip != 1 { print }
' "$HOSTS_FILE" > "$tmp.stripped"

awk '
  NF {
    for (i = 0; i < blank; i++) print ""
    blank = 0
    print
    next
  }
  { blank++ }
' "$tmp.stripped" > "$tmp"

{
  cat "$tmp"
  if [ -s "$tmp" ]; then
    printf '\n'
  fi
  cat "$tmp.block"
} > "$tmp.next"
mv "$tmp.next" "$tmp"

if cmp -s "$HOSTS_FILE" "$tmp"; then
  exit 0
fi

if [ ! -f "$BACKUP_FILE" ]; then
  cp "$HOSTS_FILE" "$BACKUP_FILE"
fi

install -m 0644 "$tmp" "$HOSTS_FILE"

if [ "$FLUSH_DNS" = "1" ]; then
  /usr/bin/dscacheutil -flushcache
  /usr/bin/killall -HUP mDNSResponder 2>/dev/null || true
fi
