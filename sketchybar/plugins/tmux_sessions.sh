#!/bin/sh

if ! command -v tmux >/dev/null 2>&1 || ! tmux list-sessions >/dev/null 2>&1; then
    sketchybar --set "$NAME" drawing=off
    exit 0
fi

active_sessions="$(tmux list-clients -F '#{client_session}' 2>/dev/null | sort -u)"
label=''

while IFS= read -r session; do
    [ -z "$session" ] && continue

    if printf '%s\n' "$active_sessions" | grep -Fqx "$session"; then
        segment="● $session"
    else
        segment="$session"
    fi

    if [ -n "$label" ]; then
        label="$label  $segment"
    else
        label="$segment"
    fi
done <<EOF
$(tmux list-sessions -F '#{session_name}' 2>/dev/null)
EOF

if [ -z "$label" ]; then
    sketchybar --set "$NAME" drawing=off
else
    sketchybar --set "$NAME" drawing=on label="$label"
fi
