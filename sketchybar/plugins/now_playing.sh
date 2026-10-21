#!/bin/sh

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar"
placeholder="$CONFIG_DIR/assets/media-placeholder.png"

set_section_flares() {
    if [ -r "$HOME/.config/desktop-theme/current/bar-flare-left.png" ]; then
        sketchybar --set '/section\.flare\.center_.*/' drawing="$1"
    fi
}

# Slide the island in from above the bar (tanh) and back out (sin).
visibility_path="$cache_dir/now-playing-visibility"
show_frames=20
hide_frames=15

hidden_offset() {
    bar_height="$(sketchybar --query bar 2>/dev/null | jq -r '.height // 40' 2>/dev/null)"
    printf '%s' "$(( ${bar_height:-40} + 8 ))"
}

set_offset() {
    sketchybar ${2:+--animate "$2" "$3"} \
        --set now_playing y_offset="$1" \
        --set now_playing.artwork y_offset="$1" \
        --set now_playing.title y_offset="$1" \
        --set '/section\.flare\.center_.*/' y_offset="$1"
}

is_drawn() {
    [ "$(sketchybar --query now_playing.title 2>/dev/null | jq -r '.geometry.drawing' 2>/dev/null)" = "on" ]
}

hide_now_playing() {
    mkdir -p "$cache_dir"
    intent="$(cat "$visibility_path" 2>/dev/null)"
    if ! is_drawn; then
        printf 'hidden\n' > "$visibility_path"
        return
    fi
    # A close animation is already running.
    case "$intent" in hidden*) return ;; esac

    token="hidden:$$:$(date +%s)"
    printf '%s\n' "$token" > "$visibility_path"
    set_offset "$(hidden_offset)" sin "$hide_frames"
    # Stop drawing once the slide finishes, unless playback resumed meanwhile.
    (
        sleep 0.35
        [ "$(cat "$visibility_path" 2>/dev/null)" = "$token" ] || exit 0
        set_section_flares off
        sketchybar \
            --set now_playing.artwork drawing=off \
            --set now_playing.title drawing=off \
            --set now_playing drawing=off
    ) >/dev/null 2>&1 &
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

bundle_identifier="$(printf '%s' "$metadata" | jq -r '.bundleIdentifier // empty')"
use_media_artwork=true
case "$bundle_identifier" in
    com.google.Chrome)
        # Chrome commonly publishes its app icon as media artwork rather than
        # the page's cover image. Prefer the intentional placeholder instead.
        use_media_artwork=false
        ;;
esac

track_key="v2|$(printf '%s' "$metadata" | jq -r '[.bundleIdentifier, .contentItemIdentifier, .title, .artist] | map(. // "") | join("|")')"
track_hash="$(printf '%s' "$track_key" | shasum -a 256 | awk '{ print substr($1, 1, 16) }')"

mkdir -p "$cache_dir"

artwork_path=""
if [ "$use_media_artwork" = "true" ]; then
    for extension in jpg png image; do
        candidate="$cache_dir/media-artwork-$track_hash.$extension"
        if [ -s "$candidate" ]; then
            artwork_path="$candidate"
            break
        fi
    done
fi

if [ "$use_media_artwork" = "true" ] && [ -z "$artwork_path" ]; then
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
    if [ "$use_media_artwork" = "false" ]; then
        find "$cache_dir" -type f -name "media-artwork-$track_hash.*" -delete 2>/dev/null
    fi
else
    find "$cache_dir" -type f -name 'media-artwork-*' ! -name "$(basename "$artwork_path")" -delete 2>/dev/null
fi

intent="$(cat "$visibility_path" 2>/dev/null)"
animate_in=false
if ! is_drawn; then
    animate_in=true
    set_offset "$(hidden_offset)"
elif [ "$intent" != "shown" ]; then
    # Playback resumed mid-close: slide back down from the current position.
    animate_in=true
fi
printf 'shown\n' > "$visibility_path"

sketchybar \
    --set now_playing.artwork drawing=on background.image="$artwork_path" \
    --set now_playing.title drawing=on label="$title" \
    --set now_playing drawing=on
set_section_flares on
if [ "$animate_in" = "true" ]; then
    set_offset 0 tanh "$show_frames"
fi
