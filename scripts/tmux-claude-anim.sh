#!/usr/bin/env bash
# Animate a sweeping bar on the border of any pane where Claude is "running".
# Reads state from tmux-agent-indicator (TMUX_AGENT_PANE_<id>_STATE env vars),
# writes the rendered bar into pane option @claude_anim, and forces a redraw.
# Self-exits when no pane is running.

set -u

PIDFILE="${TMPDIR:-/tmp}/tmux-claude-anim.pid"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
    exit 0
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

BLOCK=4
TOTAL_MIN=8

DASH="┄"
HEAVY="━"
FG_ACTIVE="#ff79c6"
FG_INACTIVE="#5a8497"

render_bar() {
    local total=$1 pos=$2 color=$3
    local i out="#[fg=${color}]"
    for ((i = 0; i < total; i++)); do
        if [ "$i" -ge "$pos" ] && [ "$i" -lt "$((pos + BLOCK))" ]; then
            out+="${HEAVY}"
        else
            out+="${DASH}"
        fi
    done
    out+="#[default]"
    printf '%s' "$out"
}

clear_all() {
    tmux list-panes -a -F '#{pane_id}' 2>/dev/null | while read -r p; do
        tmux set -p -t "$p" -u '@claude_anim_a' 2>/dev/null || true
        tmux set -p -t "$p" -u '@claude_anim_i' 2>/dev/null || true
    done
}

frame=0
while true; do
    tmux list-sessions >/dev/null 2>&1 || break

    running=()
    while IFS= read -r line; do
        case "$line" in
            TMUX_AGENT_PANE_*_STATE=running)
                p="${line#TMUX_AGENT_PANE_}"
                p="${p%_STATE=running}"
                tmux display -p -t "$p" '#{pane_id}' >/dev/null 2>&1 && running+=("$p")
                ;;
        esac
    done < <(tmux show-environment -g 2>/dev/null | grep '_STATE=running' || true)

    tmux list-panes -a -F '#{pane_id}' 2>/dev/null | while read -r p; do
        match=0
        for r in "${running[@]:-}"; do [ "$p" = "$r" ] && match=1 && break; done
        if [ "$match" -eq 0 ]; then
            tmux set -p -t "$p" -u '@claude_anim_a' 2>/dev/null || true
            tmux set -p -t "$p" -u '@claude_anim_i' 2>/dev/null || true
        fi
    done

    if [ ${#running[@]} -eq 0 ]; then
        break
    fi

    for p in "${running[@]}"; do
        pane_w=$(tmux display -p -t "$p" '#{pane_width}' 2>/dev/null) || continue
        cwd=$(tmux display -p -t "$p" '#{b:pane_current_path}' 2>/dev/null)
        path=$(tmux display -p -t "$p" '#{pane_current_path}' 2>/dev/null)
        branch=""
        if [ -n "$path" ]; then
            branch=$(cd "$path" 2>/dev/null && git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
        fi
        # prefix layout: " <cwd>" + (if branch: "  <branch>") + "  " (before bar) + " " (trailing)
        prefix=$(( 1 + ${#cwd} + 3 ))
        [ -n "$branch" ] && prefix=$(( prefix + 4 + ${#branch} ))
        total=$(( pane_w - prefix ))
        [ "$total" -lt "$TOTAL_MIN" ] && total=$TOTAL_MIN
        max_pos=$(( total - BLOCK ))
        [ "$max_pos" -lt 1 ] && max_pos=1
        cycle=$(( max_pos * 2 ))
        phase=$(( frame % cycle ))
        if [ "$phase" -le "$max_pos" ]; then
            pos=$phase
        else
            pos=$(( 2 * max_pos - phase ))
        fi
        bar_a=$(render_bar "$total" "$pos" "$FG_ACTIVE")
        bar_i=$(render_bar "$total" "$pos" "$FG_INACTIVE")
        tmux set -p -t "$p" '@claude_anim_a' "  $bar_a" 2>/dev/null || true
        tmux set -p -t "$p" '@claude_anim_i' "  $bar_i" 2>/dev/null || true
    done

    tmux refresh-client 2>/dev/null || true
    frame=$((frame + 1))
    sleep 0.05
done

clear_all
tmux refresh-client 2>/dev/null || true
