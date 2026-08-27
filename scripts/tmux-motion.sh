#!/usr/bin/env bash
# tmux の分割・終了に短いモーションを加える。
# macOS 標準の Bash 3.2 でも動作する範囲の構文に限定する。

set -u

motion_settings_loaded=0
motion_enabled_value='on'
motion_frames_value=2
motion_delay_value='0.001'

load_motion_settings() {
    local settings

    [ "$motion_settings_loaded" -eq 1 ] && return
    settings=$(
        tmux show-options -g 2>/dev/null \
            | awk '
                $1 == "@motion-enabled" { enabled = $2 }
                $1 == "@motion-frames" { frames = $2 }
                $1 == "@motion-frame-delay" { delay = $2 }
                END { printf "%s|%s|%s\n", enabled, frames, delay }
            '
    )
    IFS='|' read -r motion_enabled_value motion_frames_value motion_delay_value <<EOF
$settings
EOF

    [ -n "$motion_enabled_value" ] || motion_enabled_value='on'
    case "$motion_frames_value" in
        ''|*[!0-9]*) motion_frames_value=2 ;;
    esac
    [ "$motion_frames_value" -lt 2 ] && motion_frames_value=2
    [ "$motion_frames_value" -gt 12 ] && motion_frames_value=12
    case "$motion_delay_value" in
        0.[0-9]*|1.0) ;;
        *) motion_delay_value=0.001 ;;
    esac
    motion_settings_loaded=1
}

motion_enabled() {
    load_motion_settings
    [ "$motion_enabled_value" != "off" ]
}

motion_frames() {
    load_motion_settings
    printf '%s\n' "$motion_frames_value"
}

motion_delay() {
    load_motion_settings
    printf '%s\n' "$motion_delay_value"
}

pane_exists() {
    tmux display-message -p -t "$1" '#{pane_id}' >/dev/null 2>&1
}

balance_horizontal() {
    "$HOME/.dotfiles/scripts/tmux-balance-horizontal.sh" "${1:-}" >/dev/null 2>&1 || true
}

create_split() {
    local direction target pane_path size pane_command
    local -a split_args

    direction="$1"
    target="$2"
    pane_path="$3"
    size="${4:-}"
    pane_command="${5:-}"

    split_args=(split-window -P -F '#{pane_id}' -c "$pane_path" -t "$target")
    if [ "$direction" = "horizontal" ]; then
        split_args+=(-h)
    else
        split_args+=(-v)
    fi
    [ -n "$size" ] && split_args+=(-l "$size")

    if [ -n "$pane_command" ]; then
        tmux "${split_args[@]}" "$pane_command"
    else
        tmux "${split_args[@]}"
    fi
}

animate_split() {
    local direction target pane_path pane_command target_geometry before_size min_size new_pane
    local final_size frames delay step remaining value pane_geometry window_width top_columns window_id

    direction="$1"
    target="${2:-${TMUX_PANE:-}}"
    [ -n "$target" ] || exit 1

    pane_path="${3:-}"
    if [ -z "$pane_path" ]; then
        pane_path=$(tmux display-message -p -t "$target" '#{pane_current_path}')
    fi
    pane_command="${4:-}"
    target_geometry=$(tmux display-message -p -t "$target" '#{window_id}|#{pane_width}|#{pane_height}') || exit 1
    IFS='|' read -r window_id pane_width pane_height <<EOF
$target_geometry
EOF
    if [ "$direction" = "horizontal" ]; then
        before_size="$pane_width"
    else
        before_size="$pane_height"
    fi

    # 小さすぎるペインでは通常の分割へフォールバックする。
    if [ "$before_size" -lt 8 ] || ! motion_enabled; then
        create_split "$direction" "$target" "$pane_path" '' "$pane_command" >/dev/null || exit 1
        if [ "$direction" = "horizontal" ]; then
            balance_horizontal "$window_id"
        fi
        exit
    fi

    min_size=2
    if [ "$direction" = "horizontal" ]; then
        new_pane=$(create_split "$direction" "$target" "$pane_path" "$min_size" "$pane_command") || exit 1
        pane_geometry=$(tmux list-panes -t "$window_id" -F '#{window_width} #{pane_top}')
        window_width=$(printf '%s\n' "$pane_geometry" | awk 'NR == 1 { print $1 }')
        top_columns=$(
            printf '%s\n' "$pane_geometry" \
                | awk '
                    NR == 1 { min = $2; count = 1; next }
                    $2 < min { min = $2; count = 1; next }
                    $2 == min { count++ }
                    END { print count + 0 }
                '
        )
        if [ "$top_columns" -gt 1 ]; then
            final_size=$(((window_width - (top_columns - 1)) / top_columns))
        else
            final_size=$(((before_size - 1) / 2))
        fi
    else
        new_pane=$(create_split "$direction" "$target" "$pane_path" "$min_size" "$pane_command") || exit 1
        final_size=$(((before_size - 1) / 2))
    fi

    [ "$final_size" -le "$min_size" ] && exit

    frames=$(motion_frames)
    delay=$(motion_delay)

    # ease-out quadratic: 最初に大きく動き、終点へ柔らかく収束する。
    step=1
    while [ "$step" -le "$frames" ]; do
        remaining=$((frames - step))
        value=$((final_size - ((final_size - min_size) * remaining * remaining) / (frames * frames)))
        if [ "$direction" = "horizontal" ]; then
            tmux resize-pane -t "$new_pane" -x "$value" 2>/dev/null || break
        else
            tmux resize-pane -t "$new_pane" -y "$value" 2>/dev/null || break
        fi
        sleep "$delay"
        step=$((step + 1))
    done

    if [ "$direction" = "horizontal" ]; then
        balance_horizontal "$window_id"
    fi
}

open_rightmost() {
    local source pane_command requested_path source_info window_id source_path rightmost

    source="${1:-${TMUX_PANE:-}}"
    pane_command="${2:-}"
    requested_path="${3:-}"
    [ -n "$source" ] || exit 1

    source_info=$(tmux display-message -p -t "$source" '#{window_id}|#{pane_current_path}') || exit 1
    IFS='|' read -r window_id source_path <<EOF
$source_info
EOF
    if [ -n "$requested_path" ]; then
        if [ ! -d "$requested_path" ]; then
            tmux display-message -d 1200 "Directory not found: $requested_path"
            exit 1
        fi
        source_path=$(cd "$requested_path" 2>/dev/null && pwd -P) || exit 1
    fi
    rightmost=$(
        tmux list-panes -t "$window_id" -F '#{pane_right} #{pane_top} #{pane_id}' \
            | sort -k1,1nr -k2,2n \
            | awk 'NR == 1 { print $3 }'
    )
    [ -n "$rightmost" ] || exit 1

    animate_split horizontal "$rightmost" "$source_path" "$pane_command"
}

open_rightmost_codex() {
    local source requested_path codex_command

    source="${1:-${TMUX_PANE:-}}"
    requested_path="${2:-}"
    codex_command=$(tmux show-option -gqv @motion-codex-command 2>/dev/null)
    [ -n "$codex_command" ] || codex_command='exec zsh -ic codexc'

    open_rightmost "$source" "$codex_command" "$requested_path"
}

detect_close_axis() {
    local target="$1"
    local target_left="$2"
    local target_top="$3"
    local target_width="$4"
    local target_height="$5"
    local window_id="$6"
    local pane_id pane_left pane_top pane_width pane_height

    # このリポジトリの「ルートは左右、その内側は上下」というレイアウトを優先する。
    while read -r pane_id pane_left pane_top pane_width pane_height; do
        [ "$pane_id" = "$target" ] && continue

        if [ "$pane_left" -eq "$target_left" ] && [ "$pane_width" -eq "$target_width" ]; then
            if [ $((pane_top + pane_height + 1)) -eq "$target_top" ] || \
               [ $((target_top + target_height + 1)) -eq "$pane_top" ]; then
                printf 'vertical\n'
                return
            fi
        fi
    done < <(tmux list-panes -t "$window_id" -F '#{pane_id} #{pane_left} #{pane_top} #{pane_width} #{pane_height}')

    while read -r pane_id pane_left pane_top pane_width pane_height; do
        [ "$pane_id" = "$target" ] && continue

        if [ "$pane_top" -eq "$target_top" ] && [ "$pane_height" -eq "$target_height" ]; then
            if [ $((pane_left + pane_width + 1)) -eq "$target_left" ] || \
               [ $((target_left + target_width + 1)) -eq "$pane_left" ]; then
                printf 'horizontal\n'
                return
            fi
        fi
    done < <(tmux list-panes -t "$window_id" -F '#{pane_id} #{pane_left} #{pane_top} #{pane_width} #{pane_height}')

    # 複雑な入れ子では、縮められる可能性が高い短辺を選ぶ。
    if [ "$target_height" -lt "$target_width" ]; then
        printf 'vertical\n'
    else
        printf 'horizontal\n'
    fi
}

animate_close() {
    local target geometry pane_width pane_height pane_left pane_top
    local window_width window_height window_id pane_count axis initial_size
    local min_size frames delay step value

    target="${1:-}"
    [ -n "$target" ] || exit 1
    pane_exists "$target" || exit

    # 途中で失敗しても dead pane を残さない。
    trap 'tmux kill-pane -t "'"$target"'" >/dev/null 2>&1 || true' EXIT HUP INT TERM

    geometry=$(tmux display-message -p -t "$target" \
        '#{pane_width} #{pane_height} #{pane_left} #{pane_top} #{window_width} #{window_height} #{window_id}') || exit
    read -r pane_width pane_height pane_left pane_top window_width window_height window_id <<EOF
$geometry
EOF

    pane_count=$(tmux list-panes -t "$window_id" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$pane_count" -le 1 ] || ! motion_enabled; then
        exit
    fi

    axis=$(detect_close_axis "$target" "$pane_left" "$pane_top" "$pane_width" "$pane_height" "$window_id")
    if [ "$axis" = "vertical" ]; then
        initial_size="$pane_height"
    else
        initial_size="$pane_width"
    fi

    min_size=1
    frames=$(motion_frames)
    delay=$(motion_delay)

    # ease-in quadratic: 静かに始まり、最後だけ素早く閉じる。
    step=1
    while [ "$step" -le "$frames" ]; do
        value=$((initial_size - ((initial_size - min_size) * step * step) / (frames * frames)))
        [ "$value" -lt "$min_size" ] && value="$min_size"
        if [ "$axis" = "vertical" ]; then
            tmux resize-pane -t "$target" -y "$value" 2>/dev/null || break
        else
            tmux resize-pane -t "$target" -x "$value" 2>/dev/null || break
        fi
        sleep "$delay"
        step=$((step + 1))
    done

    exit
}

soft_close() {
    local target geometry pane_width pane_height pane_left pane_top
    local window_id pane_count axis initial_size min_size frames delay step value
    local previous_undo_window undo_window

    target="${1:-}"
    [ -n "$target" ] || exit 1

    geometry=$(tmux display-message -p -t "$target" \
        '#{pane_width} #{pane_height} #{pane_left} #{pane_top} #{window_id} #{window_panes}') || exit 1
    read -r pane_width pane_height pane_left pane_top window_id pane_count <<EOF
$geometry
EOF

    # 最後の1ペインはbreak-paneできないため、誤操作として何もしない。
    if [ "$pane_count" -le 1 ]; then
        tmux display-message -d 900 'Last pane kept open'
        exit
    fi

    # Undoは1段だけ保持し、新しい退避時に古い退避windowを破棄する。
    previous_undo_window=$(tmux show-option -gqv @motion-undo-window 2>/dev/null)
    if [ -n "$previous_undo_window" ] && \
       tmux display-message -p -t "$previous_undo_window" '#{window_id}' >/dev/null 2>&1; then
        tmux kill-window -t "$previous_undo_window" >/dev/null 2>&1 || true
    fi

    axis=$(detect_close_axis "$target" "$pane_left" "$pane_top" "$pane_width" "$pane_height" "$window_id")
    if [ "$axis" = "vertical" ]; then
        initial_size="$pane_height"
    else
        initial_size="$pane_width"
    fi

    if motion_enabled; then
        min_size=1
        frames=$(motion_frames)
        delay=$(motion_delay)
        step=1
        while [ "$step" -le "$frames" ]; do
            value=$((initial_size - ((initial_size - min_size) * step * step) / (frames * frames)))
            [ "$value" -lt "$min_size" ] && value="$min_size"
            if [ "$axis" = "vertical" ]; then
                tmux resize-pane -t "$target" -y "$value" 2>/dev/null || break
            else
                tmux resize-pane -t "$target" -x "$value" 2>/dev/null || break
            fi
            sleep "$delay"
            step=$((step + 1))
        done
    fi

    undo_window=$(tmux break-pane -d -P -F '#{window_id}' -s "$target" -n '__pane_undo__') || exit 1
    tmux set-option -gq @motion-undo-pane "$target"
    tmux set-option -gq @motion-undo-window "$undo_window"
    balance_horizontal "$window_id"
}

animate_restored_pane() {
    local target window_id geometry current_size window_width top_columns final_size
    local frames delay step remaining value

    target="$1"
    window_id="$2"
    geometry=$(tmux display-message -p -t "$target" '#{pane_width} #{window_width}') || return
    read -r current_size window_width <<EOF
$geometry
EOF

    top_columns=$(
        tmux list-panes -t "$window_id" -F '#{pane_top}' \
            | awk '
                NR == 1 { min = $1; count = 1; next }
                $1 < min { min = $1; count = 1; next }
                $1 == min { count++ }
                END { print count + 0 }
            '
    )
    final_size=$(((window_width - (top_columns - 1)) / top_columns))

    if motion_enabled && [ "$final_size" -gt "$current_size" ]; then
        frames=$(motion_frames)
        delay=$(motion_delay)
        step=1
        while [ "$step" -le "$frames" ]; do
            remaining=$((frames - step))
            value=$((final_size - ((final_size - current_size) * remaining * remaining) / (frames * frames)))
            tmux resize-pane -t "$target" -x "$value" 2>/dev/null || break
            sleep "$delay"
            step=$((step + 1))
        done
    fi

    balance_horizontal "$window_id"
}

undo_last_pane() {
    local target undo_pane window_id rightmost

    target="${1:-${TMUX_PANE:-}}"
    undo_pane=$(tmux show-option -gqv @motion-undo-pane 2>/dev/null)
    if [ -z "$undo_pane" ] || ! pane_exists "$undo_pane"; then
        tmux set-option -gu @motion-undo-pane 2>/dev/null || true
        tmux set-option -gu @motion-undo-window 2>/dev/null || true
        tmux display-message -d 700 'No pane to restore'
        exit
    fi

    window_id=$(tmux display-message -p -t "$target" '#{window_id}') || exit 1
    rightmost=$(
        tmux list-panes -t "$window_id" -F '#{pane_right} #{pane_top} #{pane_id}' \
            | sort -k1,1nr -k2,2n \
            | awk 'NR == 1 { print $3 }'
    )
    [ -n "$rightmost" ] || exit 1

    tmux join-pane -h -l 2 -s "$undo_pane" -t "$rightmost" || exit 1
    tmux set-option -gu @motion-undo-pane 2>/dev/null || true
    tmux set-option -gu @motion-undo-window 2>/dev/null || true
    animate_restored_pane "$undo_pane" "$window_id"
}

case "${1:-}" in
    split-horizontal)
        animate_split horizontal "${2:-}"
        ;;
    split-vertical)
        animate_split vertical "${2:-}"
        ;;
    open-rightmost)
        open_rightmost "${2:-}" '' "${3:-}"
        ;;
    open-rightmost-codex)
        open_rightmost_codex "${2:-}" "${3:-}"
        ;;
    close-pane)
        animate_close "${2:-}"
        ;;
    soft-close-pane)
        soft_close "${2:-}"
        ;;
    undo-last-pane)
        undo_last_pane "${2:-}"
        ;;
    *)
        printf 'usage: %s {split-horizontal|split-vertical|open-rightmost|open-rightmost-codex|close-pane|soft-close-pane|undo-last-pane} [target] [path]\n' "$0" >&2
        exit 2
        ;;
esac
