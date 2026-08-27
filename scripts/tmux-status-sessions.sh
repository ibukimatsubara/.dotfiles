#!/usr/bin/env bash
# 左にPomodoro、中央にセッション、右に場所と時刻を置く一行ステータス。
# $1: 現在のセッション名, $2: クライアント幅, $3: 現在のパス

current="${1:-}"
width="${2:-0}"
current_path="${3:-}"

canvas='default'
ink='#0d1117'
surface='#161b22'
muted='#8b949e'
accent='#5eead4'
blue='#58a6ff'
amber='#fbbf24'
purple='#c084fc'

left_plain=''
left_output=''

timer_status_path="${TMUX_BREAK_TIMER_STATUS_FILE:-$HOME/.cache/ghostty-break/tmux_status.tsv}"
now_epoch="${TMUX_STATUS_NOW_EPOCH:-$(date +%s)}"
if [ -r "$timer_status_path" ]; then
    IFS=$'\t' read -r timer_enabled timer_state timer_start timer_duration < "$timer_status_path"
    if [[ "$timer_start" =~ ^[0-9]+$ ]] \
        && [[ "$timer_duration" =~ ^[0-9]+$ ]] \
        && [[ "$now_epoch" =~ ^[0-9]+$ ]]; then
        timer_color="$muted"
        timer_label='◷ off'

        if [ "$timer_enabled" = 'true' ]; then
            case "$timer_state" in
                work) timer_color="$accent" ;;
                snoozed) timer_color="$amber" ;;
                fading) timer_color="$blue" ;;
                break) timer_color="$purple" ;;
                waiting)
                    timer_color="$accent"
                    timer_label='◷ ready'
                    ;;
                *) timer_state='' ;;
            esac

            if [ -n "$timer_state" ] && [ "$timer_state" != 'waiting' ]; then
                elapsed=$((now_epoch - timer_start))
                [ "$elapsed" -lt 0 ] && elapsed=0
                remaining=$((timer_duration - elapsed))
                [ "$remaining" -lt 0 ] && remaining=0
                printf -v timer_clock '%02d:%02d' $((remaining / 60)) $((remaining % 60))
                timer_label="◷ ${timer_clock}"
            fi
        fi

        if [ -n "${timer_state:-}" ] || [ "$timer_enabled" != 'true' ]; then
            left_plain="  ${timer_label}"
            left_output="#[fg=${timer_color},bg=${canvas},bold]  ${timer_label}#[nobold]"
        fi
    fi
fi

center_plain=''
center_output=''
while IFS= read -r session; do
    if [ -n "$center_plain" ]; then
        center_plain+=' '
        center_output+="#[bg=${canvas}] "
    fi

    center_plain+=" ${session} "
    if [ "$session" = "$current" ]; then
        center_output+="#[fg=${accent},bg=${canvas}]#[fg=${ink},bg=${accent},bold] ${session} #[fg=${accent},bg=${canvas},nobold]"
    else
        center_output+="#[fg=${surface},bg=${canvas}]#[fg=${muted},bg=${surface}] ${session} #[fg=${surface},bg=${canvas}]"
    fi
done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null)

if [ "$current_path" = "$HOME" ]; then
    path_label='~'
else
    path_label="${current_path##*/}"
fi
[ -z "$path_label" ] && path_label='/'

right_plain="${path_label} · $(date '+%H:%M')  "
right_output="#[fg=${muted},bg=${canvas}]${path_label} #[fg=#30363d]· #[fg=${muted}]$(date '+%H:%M')  "

left_len=${#left_plain}
center_len=${#center_plain}
right_len=${#right_plain}

case "$width" in
    ''|*[!0-9]*) width=0 ;;
esac

center_start=$(( (width - center_len) / 2 ))
[ "$center_start" -lt $((left_len + 1)) ] && center_start=$((left_len + 1))
right_start=$((width - right_len))

# 幅が足りなければ、操作に重要なセッション表示を優先する。
if [ $((center_start + center_len + 1)) -gt "$right_start" ]; then
    right_plain=''
    right_output=''
    right_len=0
    right_start="$width"
fi

pad_before_center=$((center_start - left_len))
[ "$pad_before_center" -lt 1 ] && pad_before_center=1
pad_before_right=$((right_start - center_start - center_len))
[ "$pad_before_right" -lt 0 ] && pad_before_right=0

printf '%s%*s%s%*s%s#[default]\n' \
    "$left_output" "$pad_before_center" '' \
    "$center_output" "$pad_before_right" '' "$right_output"
