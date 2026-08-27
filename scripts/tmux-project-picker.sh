#!/usr/bin/env bash
# Cmd+T/R用のproject picker。保存path・tmux・履歴・zoxideを軽量に統合する。
# macOS標準のBash 3.2で動く構文だけを使う。

set -u
umask 077

history_file="${TMUX_PROJECT_HISTORY_FILE:-$HOME/.cache/tmux/project-history}"
saved_file="${TMUX_PROJECT_PATHS_FILE:-$HOME/.config/tmux/project-paths}"
motion_script="${TMUX_PROJECT_MOTION_SCRIPT:-$HOME/.dotfiles/scripts/tmux-motion.sh}"
candidate_file=''

cleanup() {
    if [ -n "$candidate_file" ] && [ -f "$candidate_file" ]; then
        rm -f "$candidate_file"
    fi
}
trap cleanup EXIT HUP INT TERM

normalize_path() {
    local input base

    input="$1"
    base="${2:-$PWD}"
    case "$input" in
        '~') input="$HOME" ;;
        '~/'*) input="$HOME/${input#\~/}" ;;
    esac
    case "$input" in
        /*) ;;
        *) input="$base/$input" ;;
    esac

    [ -d "$input" ] || return 1
    (cd "$input" 2>/dev/null && pwd -P)
}

display_path() {
    case "$1" in
        "$HOME") printf '~\n' ;;
        "$HOME"/*) printf '~%s\n' "${1#$HOME}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

append_candidate() {
    local kind path canonical display

    kind="$1"
    path="$2"
    case "$path" in
        ''|*$'\t'*|*$'\n'*|*$'\r'*) return ;;
    esac
    canonical=$(normalize_path "$path" / 2>/dev/null) || return
    display=$(display_path "$canonical")
    printf '%s\t%s\t%s\n' "$kind" "$display" "$canonical" >> "$candidate_file"
}

build_candidates() {
    local current_path path

    current_path="$1"
    candidate_file=$(mktemp "${TMPDIR:-/tmp}/tmux-project-picker.XXXXXX") || return 1
    append_candidate '● current' "$current_path"

    if [ -f "$saved_file" ]; then
        while IFS= read -r path; do
            append_candidate '★ saved ' "$path"
        done < "$saved_file"
    fi

    if [ "${TMUX_PROJECT_SKIP_TMUX:-0}" != '1' ] && command -v tmux >/dev/null 2>&1; then
        while IFS= read -r path; do
            append_candidate '◆ open  ' "$path"
        done < <(tmux list-panes -a -F '#{pane_current_path}' 2>/dev/null)
    fi

    if [ -f "$history_file" ]; then
        while IFS= read -r path; do
            append_candidate '↺ recent' "$path"
        done < "$history_file"
    fi

    if [ "${TMUX_PROJECT_SKIP_ZOXIDE:-0}" != '1' ] && command -v zoxide >/dev/null 2>&1; then
        while IFS= read -r path; do
            append_candidate 'z smart ' "$path"
        done < <(zoxide query -l 2>/dev/null)
    fi

    awk -F '\t' '!seen[$3]++' "$candidate_file"
    rm -f "$candidate_file"
    candidate_file=''
}

record_history() {
    local path cache_dir temp_file

    path=$(normalize_path "$1" / 2>/dev/null) || return 1
    cache_dir=$(dirname "$history_file")
    mkdir -p "$cache_dir"
    temp_file=$(mktemp "$cache_dir/.project-history.XXXXXX") || return 1
    {
        printf '%s\n' "$path"
        if [ -f "$history_file" ]; then
            awk -v selected="$path" '$0 != selected' "$history_file"
        fi
    } | awk 'NR <= 100' > "$temp_file"
    chmod 600 "$temp_file"
    mv "$temp_file" "$history_file"
}

save_path() {
    local path config_dir

    path=$(normalize_path "$1" "${2:-$PWD}" 2>/dev/null) || return 1
    case "$path" in
        *$'\t'*|*$'\n'*|*$'\r'*) return 1 ;;
    esac
    config_dir=$(dirname "$saved_file")
    mkdir -p "$config_dir"
    touch "$saved_file"
    chmod 600 "$saved_file"
    if ! awk -v selected="$path" '$0 == selected { found = 1 } END { exit !found }' "$saved_file"; then
        printf '%s\n' "$path" >> "$saved_file"
    fi
    printf '%s\n' "$path"
}

prompt_for_path() {
    local current_path entered normalized

    current_path="$1"
    while true; do
        printf '\033[2J\033[H' >&2
        printf '\n  Add project path\n\n' >&2
        printf '  Current: %s\n' "$(display_path "$current_path")" >&2
        printf '  Tab completes folders · empty input returns to the list\n\n' >&2
        IFS= read -e -r -p '  path › ' entered || return 1
        [ -n "$entered" ] || return 1
        if normalized=$(save_path "$entered" "$current_path"); then
            printf '%s\n' "$normalized"
            return
        fi
        printf '\n  Directory not found. Press Enter and try again.' >&2
        IFS= read -r _ || return 1
    done
}

run_picker() {
    local current_path

    current_path="$1"
    build_candidates "$current_path" | fzf \
        --ansi \
        --layout=reverse \
        --border=rounded \
        --disabled \
        --no-input \
        --expect=a \
        --delimiter=$'\t' \
        --with-nth=1,2 \
        --no-multi \
        --info=inline-right \
        --pointer='▶' \
        --prompt='project › ' \
        --header=$'j/k move  ·  Enter open  ·  a add\n/ search  ·  q close' \
        --bind='j:down,k:up,q:abort,/:enable-search+show-input+unbind(j,k,a,q,/)+change-prompt(search\ ›\ )' \
        --bind='ctrl-j:down,ctrl-k:up' \
        --preview='printf "\033[1;36m%s\033[0m\n\n" {3}; command ls -Ap -- {3} 2>/dev/null | sed -n "1,120p"' \
        --preview-window='right,45%,border-left' \
        --color='bg:#161b22,bg+:#21262d,fg:#8b949e,fg+:#f0f6fc,hl:#58a6ff,hl+:#5eead4,pointer:#5eead4,header:#6e7681,border:#30363d,prompt:#5eead4'
}

open_selected() {
    local mode source path action

    mode="$1"
    source="$2"
    path="$3"
    action='open-rightmost'
    [ "$mode" = 'codex' ] && action='open-rightmost-codex'

    if "$motion_script" "$action" "$source" "$path"; then
        record_history "$path"
        return
    fi
    tmux display-message -d 1200 'Could not open the selected project' 2>/dev/null || true
    return 1
}

picker_main() {
    local mode source current_path result pressed selected_row selected_path added_path

    mode="${1:-}"
    source="${2:-${TMUX_PANE:-}}"
    current_path="${3:-$PWD}"
    case "$mode" in shell|codex) ;; *) return 2 ;; esac
    [ -n "$source" ] || return 2
    current_path=$(normalize_path "$current_path" "$PWD" 2>/dev/null) || current_path="$PWD"

    if ! command -v fzf >/dev/null 2>&1; then
        tmux display-message -d 1400 'fzf is required for the project picker' 2>/dev/null || true
        return 1
    fi

    while true; do
        result=$(run_picker "$current_path") || return 0
        pressed=$(printf '%s\n' "$result" | sed -n '1p')
        selected_row=$(printf '%s\n' "$result" | sed -n '2p')

        if [ "$pressed" = 'a' ]; then
            added_path=$(prompt_for_path "$current_path") || continue
            open_selected "$mode" "$source" "$added_path"
            return
        fi

        selected_path=$(printf '%s\n' "$selected_row" | awk -F '\t' '{ print $3 }')
        [ -n "$selected_path" ] || continue
        open_selected "$mode" "$source" "$selected_path"
        return
    done
}

case "${1:-}" in
    --list)
        build_candidates "${2:-$PWD}"
        ;;
    --record)
        record_history "${2:-}"
        ;;
    --add)
        save_path "${2:-}" "${3:-$PWD}" >/dev/null
        ;;
    *)
        picker_main "$@"
        ;;
esac
