#!/bin/sh
set -eu

LABEL="com.local.enforceblocklist"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
SCRIPT_SRC="$DOTFILES_DIR/scripts/enforce-blocklist.sh"
PLIST_SRC="$DOTFILES_DIR/launchd/$LABEL.plist"
SCRIPT_DST="/usr/local/bin/enforce-blocklist.sh"
PLIST_DST="/Library/LaunchDaemons/$LABEL.plist"

if [ ! -f "$SCRIPT_SRC" ]; then
  echo "missing: $SCRIPT_SRC" >&2
  exit 1
fi

if [ ! -f "$PLIST_SRC" ]; then
  echo "missing: $PLIST_SRC" >&2
  exit 1
fi

sudo install -d -m 0755 -o root -g wheel /usr/local/bin
sudo install -m 0755 -o root -g wheel "$SCRIPT_SRC" "$SCRIPT_DST"
sudo install -m 0644 -o root -g wheel "$PLIST_SRC" "$PLIST_DST"

sudo launchctl bootout "system/$LABEL" 2>/dev/null || true
sudo launchctl enable "system/$LABEL" 2>/dev/null || true
sudo launchctl bootstrap system "$PLIST_DST"
sudo launchctl enable "system/$LABEL"
sudo launchctl kickstart -k "system/$LABEL"

echo "blocklist on"
echo "status: sudo launchctl print system/$LABEL"
