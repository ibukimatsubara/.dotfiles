#!/bin/sh
# Mirror Pomoru's status export (the same JSON the Caelestia bar reads on Ubuntu).

# shellcheck source=/dev/null
. "$CONFIG_DIR/colors.sh"

case "$(uname -s)" in
    Darwin) status_path="$HOME/Library/Caches/pomoru/status.json" ;;
    *) status_path="${XDG_CACHE_HOME:-$HOME/.cache}/pomoru/status.json" ;;
esac
status_path="${POMORU_STATUS_FILE:-$status_path}"
# Pomoru exports every second even while paused; a frozen countdown means paused.
state_path="${TMPDIR:-/tmp}/sketchybar-pomoru-${NAME:-pomodoro}"

show_off() {
    rm -f "$state_path"
    sketchybar --set "$NAME" icon="󰔛" icon.color="$FOCUS_COLOR" label="OFF" label.color="$FOCUS_COLOR"
    exit 0
}

# Pomoru removes the file on quit; also ignore a stale file left by a closed terminal.
[ -r "$status_path" ] || show_off
pgrep -x pomoru >/dev/null 2>&1 || show_off

status="$(jq -r 'select((.text | type) == "string" and (.class | type) == "string")
    | [.class, (.text | capture("(?<t>[0-9]+:[0-9]+(:[0-9]+)?)").t)] | @tsv' \
    "$status_path" 2>/dev/null)" || status=""
# Pomoru truncates before writing; keep the current label on a partial read.
[ -n "$status" ] || exit 0

IFS="$(printf '\t')" read -r class remaining <<EOF
$status
EOF

case "$class" in
    work) icon="󰔛"; color="$GREEN_COLOR" ;;
    short-break) icon=""; color="$MAUVE_COLOR" ;;
    long-break) icon="󰒲"; color="$BLUE_COLOR" ;;
    *) icon="󰔛"; color="$FOCUS_COLOR" ;;
esac

now="$(date +%s)"
previous_key=""
since="$now"
[ -r "$state_path" ] && read -r previous_key since < "$state_path"
key="$class:$remaining"
if [ "$key" != "$previous_key" ]; then
    since="$now"
    printf '%s %s\n' "$key" "$since" > "$state_path"
fi
if [ $((now - since)) -ge 3 ]; then
    icon="󰏤"
    color="$MUTED_COLOR"
fi

sketchybar --set "$NAME" icon="$icon" icon.color="$color" label="$remaining" label.color="$color"
