#!/usr/bin/env bash
# Headless screen capture; systemd owns the recorder and finalizes it on stop.
set -euo pipefail
umask 077

action="${1:-toggle}"
format="${2:-mp4}"
case "$format" in mp4|gif) ;; *) echo 'Expected mp4 or gif' >&2; exit 2 ;; esac
runtime="${XDG_RUNTIME_DIR:?}/dotfiles-screen-record"
mkdir -p "$runtime"
capture="$runtime/$format.mp4"
unit="dotfiles-screen-record@$format.service"

case "$action" in
    toggle)
        exec 9>"$runtime/toggle.lock"
        flock -n 9 || exit 0
        for candidate in mp4 gif; do
            candidate_unit="dotfiles-screen-record@$candidate.service"
            state="$(systemctl --user show -p ActiveState --value "$candidate_unit")"
            case "$state" in
                active|activating|deactivating)
                    systemctl --user stop "$candidate_unit"
                    exit 0
                    ;;
            esac
        done
        systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
        systemctl --user start "$unit"
        ;;
    capture)
        monitor="$(hyprctl -j monitors | jq -er '.[] | select(.focused) | .name')"
        notify-send '録画を開始しました' '同じ録画ショートカットをもう一度押すと停止'
        exec wf-recorder -y -o "$monitor" -r 30 -c libx264 \
            -p preset=ultrafast -p crf=23 -x yuv420p -f "$capture"
        ;;
    finish)
        if [[ "${SERVICE_RESULT:-}" != success || ! -s "$capture" ]]; then
            notify-send -u critical '録画に失敗しました' "journalctl --user -u $unit で詳細を確認できます"
            exit 1
        fi
        video_dir="${XDG_VIDEOS_DIR:-$HOME/Videos}/ScreenRecordings"
        mkdir -p "$video_dir"
        output="$(mktemp "$video_dir/$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX.$format")"
        if [[ "$format" == gif ]]; then
            if ! ffmpeg -nostdin -hide_banner -loglevel error -y -i "$capture" \
                -filter_complex 'fps=12,scale=960:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse' \
                "$output"; then
                rm -f "$output"
                notify-send -u critical 'GIFへの変換に失敗しました' "$capture"
                exit 1
            fi
            rm -f "$capture"
        else
            mv "$capture" "$output"
        fi
        uri="$(python3 - "$output" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).as_uri())
PY
        )"
        # Keep the clipboard owner alive after the recorder's service exits.
        systemd-run --user --quiet --collect --service-type=exec \
            --setenv=WAYLAND_DISPLAY \
            wl-copy --foreground --type text/uri-list "$uri"$'\r\n'
        notify-send '録画を保存してコピーしました' "$output"
        ;;
    *) echo 'Expected toggle, capture, or finish' >&2; exit 2 ;;
esac
