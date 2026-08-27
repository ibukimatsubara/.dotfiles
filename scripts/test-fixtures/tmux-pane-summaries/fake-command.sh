#!/usr/bin/env bash

set -u

command_name="${0##*/}"
state_file="${FAKE_TMUX_STATE:?}"

fake_tmux() {
    action="${1:-}"
    shift || true

    case "$action" in
        list-sessions)
            return 0
            ;;
        list-panes)
            pane_number=1
            pane_count="${FAKE_PANE_COUNT:-1}"
            while [ "$pane_number" -le "$pane_count" ]; do
                printf '%%%s\tcodex\t/tmp/project-%s\t0\n' "$pane_number" "$pane_number"
                pane_number=$((pane_number + 1))
            done
            ;;
        capture-pane)
            printf 'capture-locale=%s\n' "${LC_ALL:-${LANG:-unset}}" >> "$state_file"
            printf '%s\n' 'Implementing a resilient tmux pane summary worker'
            ;;
        show-option)
            option="${!#}"
            case "$option" in
                @pane-summary-enabled) printf '%s\n' 'on' ;;
                @pane-summary-model) printf '%s\n' 'gpt-5.6-luna' ;;
                @pane-summary-capture-lines) printf '%s\n' '5' ;;
                @pane-summary-max-input-chars) printf '%s\n' '500' ;;
                @pane-summary-max-title-chars) printf '%s\n' '34' ;;
                @pane-summary-max-panes) printf '%s\n' "${FAKE_MAX_PANES:-2}" ;;
                @pane-summary-max-total-input-chars) printf '%s\n' "${FAKE_MAX_TOTAL_INPUT_CHARS:-1000}" ;;
                @pane-summary-timeout-seconds) printf '%s\n' "${FAKE_TIMEOUT_SECONDS:-2}" ;;
                @pane-summary-max-rss-mb) printf '%s\n' "${FAKE_MAX_RSS_MB:-256}" ;;
                @pane-summary-max-output-bytes) printf '%s\n' '16384' ;;
                @pane-summary-watchdog-interval-seconds) printf '%s\n' '1' ;;
                @pane-summary-kill-grace-seconds) printf '%s\n' '1' ;;
                @pane-summary)
                    sed -n 's/^summary=//p' "$state_file" 2>/dev/null | tail -n 1
                    ;;
            esac
            ;;
        set-option)
            previous=''
            for argument in "$@"; do
                if [ "$previous" = '@pane-summary' ]; then
                    printf 'summary=%s\n' "$argument" >> "$state_file"
                    return 0
                fi
                previous="$argument"
            done
            return 0
            ;;
        refresh-client)
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}

fake_codex() {
    output_file=''
    model=''
    previous=''
    for argument in "$@"; do
        if [ "$previous" = '--output-last-message' ]; then
            output_file="$argument"
        fi
        if [ "$previous" = '--model' ] || [ "$previous" = '-m' ]; then
            model="$argument"
        fi
        previous="$argument"
    done
    printf 'model=%s\n' "$model" >> "$state_file"
    while IFS= read -r _line; do :; done

    case "${FAKE_CODEX_MODE:-success}" in
        success)
            printf '%s\n' '{"summaries":[{"pane_id":"%1","summary":"pane要約の安全対策を実装済みで待機中"}]}' > "$output_file"
            ;;
        malformed)
            printf '%s\n' 'not-json' > "$output_file"
            ;;
        oversized)
            /usr/bin/perl -e 'print "x" x 20000' > "$output_file"
            ;;
        connection-error)
            exit 75
            ;;
        hang-child)
            /bin/sleep 600 &
            child_pid=$!
            printf '%s\n' "$child_pid" > "${FAKE_CHILD_PID_FILE:?}"
            wait "$child_pid"
            ;;
        memory)
            /usr/bin/perl -e '
                open my $fh, ">", $ENV{"FAKE_CHILD_PID_FILE"} or die $!;
                print {$fh} "$$\n";
                close $fh;
                my $memory = "x" x (96 * 1024 * 1024);
                sleep 600;
            ' &
            child_pid=$!
            wait "$child_pid"
            ;;
        *)
            exit 64
            ;;
    esac
}

case "$command_name" in
    tmux) fake_tmux "$@" ;;
    codex) fake_codex "$@" ;;
    *) exit 64 ;;
esac
