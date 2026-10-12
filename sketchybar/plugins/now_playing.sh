#!/bin/sh

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar"
placeholder="$CONFIG_DIR/assets/media-placeholder.png"

hide_now_playing() {
    sketchybar \
        --set now_playing.artwork drawing=off \
        --set now_playing.title drawing=off \
        --set now_playing drawing=off
}

if ! command -v media-control >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    hide_now_playing
    exit 0
fi

metadata="$(media-control get --no-artwork 2>/dev/null)"
if [ -z "$metadata" ] || ! printf '%s' "$metadata" | jq -e . >/dev/null 2>&1; then
    hide_now_playing
    exit 0
fi

playing="$(printf '%s' "$metadata" | jq -r '.playing // false')"
title="$(printf '%s' "$metadata" | jq -r '.title // empty')"
if [ "$playing" != "true" ] || [ -z "$title" ]; then
    hide_now_playing
    exit 0
fi

track_key="v2|$(printf '%s' "$metadata" | jq -r '[.bundleIdentifier, .contentItemIdentifier, .title, .artist] | map(. // "") | join("|")')"
track_hash="$(printf '%s' "$track_key" | shasum -a 256 | awk '{ print substr($1, 1, 16) }')"

mkdir -p "$cache_dir"

artwork_path=""
for extension in jpg png image; do
    candidate="$cache_dir/media-artwork-$track_hash.$extension"
    if [ -s "$candidate" ]; then
        artwork_path="$candidate"
        break
    fi
done

if [ -z "$artwork_path" ]; then
    payload="$(media-control get 2>/dev/null)"
    artwork_data="$(printf '%s' "$payload" | jq -r '.artworkData // empty' 2>/dev/null)"
    artwork_mime="$(printf '%s' "$payload" | jq -r '.artworkMimeType // empty' 2>/dev/null)"

    case "$artwork_mime" in
        image/png) extension="png" ;;
        image/jpeg|image/jpg) extension="jpg" ;;
        *) extension="image" ;;
    esac

    if [ -n "$artwork_data" ]; then
        source_file="$(mktemp "$cache_dir/.media-artwork-source.XXXXXX")"
        cropped_file="$source_file.cropped"
        candidate="$cache_dir/media-artwork-$track_hash.$extension"

        if printf '%s' "$artwork_data" | /usr/bin/base64 -D > "$source_file" 2>/dev/null; then
            width="$(/usr/bin/sips -g pixelWidth "$source_file" 2>/dev/null | awk '/pixelWidth/ { print $2 }')"
            height="$(/usr/bin/sips -g pixelHeight "$source_file" 2>/dev/null | awk '/pixelHeight/ { print $2 }')"

            case "$width:$height" in
                *[!0-9:]*|:*|*:)
                    ;;
                *)
                    side="$width"
                    [ "$height" -lt "$side" ] && side="$height"
                    if /usr/bin/sips \
                        --cropToHeightWidth "$side" "$side" \
                        "$source_file" \
                        --out "$cropped_file" >/dev/null 2>&1 \
                        && /usr/bin/sips \
                            --resampleHeightWidth 64 64 \
                            "$cropped_file" \
                            --out "$candidate" >/dev/null 2>&1; then
                        artwork_path="$candidate"
                    fi
                    ;;
            esac
        fi

        rm -f "$source_file" "$cropped_file"
    fi
fi

if [ -z "$artwork_path" ]; then
    artwork_path="$placeholder"
else
    find "$cache_dir" -type f -name 'media-artwork-*' ! -name "$(basename "$artwork_path")" -delete 2>/dev/null
fi

sketchybar \
    --set now_playing.artwork drawing=on background.image="$artwork_path" \
    --set now_playing.title drawing=on label="$title" \
    --set now_playing drawing=on
