#!/bin/sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar"
CACHE_FILE="$CACHE_DIR/weather.json"

# shellcheck source=/dev/null
. "$CONFIG_DIR/colors.sh"

mkdir -p "$CACHE_DIR"

temporary_file="$(mktemp "$CACHE_DIR/.weather.XXXXXX")"
trap 'rm -f "$temporary_file"' EXIT

if curl --fail --silent --show-error --max-time 10 \
    'https://wttr.in/?format=j1' > "$temporary_file" 2>/dev/null \
    && jq -e '.current_condition[0].temp_C' "$temporary_file" >/dev/null 2>&1; then
    mv "$temporary_file" "$CACHE_FILE"
    trap - EXIT
fi

if [ ! -s "$CACHE_FILE" ]; then
    sketchybar --set "$NAME" \
        icon="󰖐" \
        icon.color="$STATUS_ICON_COLOR" \
        label="--° 󰖌--%" \
        label.color="$MUTED_COLOR"
    exit 0
fi

temperature="$(jq -r '.current_condition[0].temp_C // "--"' "$CACHE_FILE")"
humidity="$(jq -r '.current_condition[0].humidity // "--"' "$CACHE_FILE")"
weather_code="$(jq -r '.current_condition[0].weatherCode // ""' "$CACHE_FILE")"

case "$weather_code" in
    113)
        weather_icon="󰖙"
        ;;
    116)
        weather_icon="󰖕"
        ;;
    119|122)
        weather_icon="󰖐"
        ;;
    143|248|260)
        weather_icon="󰖑"
        ;;
    176|263|266|281|284|293|296|299|302|305|308|311|314|317|350|353|356|359)
        weather_icon="󰖗"
        ;;
    179|182|185|227|230|320|323|326|329|332|335|338|362|365|368|371|374|377)
        weather_icon="󰖘"
        ;;
    200|386|389|392|395)
        weather_icon="󰖓"
        ;;
    *)
        weather_icon="󰖐"
        ;;
esac

sketchybar --set "$NAME" \
    icon="$weather_icon" \
    icon.color="$STATUS_ICON_COLOR" \
    label="${temperature}° 󰖌${humidity}%" \
    label.color="$TEXT_COLOR"
