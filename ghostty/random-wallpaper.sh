#!/bin/bash
# Ghostty起動時にランダムな壁紙を選択するスクリプト

WALLPAPER_DIR="$HOME/.dotfiles/ghostty/wallpapers"
CONFIG_FILE="$HOME/.dotfiles/ghostty/config"
CACHE_DIR="$HOME/.cache/ghostty-wallpapers"

prepare_wallpaper() {
    local input="$1"
    local ext="${input##*.}"
    ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"

    case "$ext" in
        jpg|jpeg|png)
            printf '%s\n' "$input"
            return 0
            ;;
    esac

    mkdir -p "$CACHE_DIR"

    local base="${input##*/}"
    local stem="${base%.*}"
    local safe_stem
    safe_stem="$(printf '%s' "$stem" | tr -c 'A-Za-z0-9._-' '_')"
    local hash
    hash="$(printf '%s' "$input" | md5 -q 2>/dev/null || printf '%s' "$input" | shasum | awk '{print $1}')"
    local output="$CACHE_DIR/${safe_stem}-${hash}.png"

    if [ ! -f "$output" ] || [ "$input" -nt "$output" ]; then
        magick "${input}[0]" "$output" || return 1
    fi

    printf '%s\n' "$output"
}

is_native_wallpaper() {
    case "$1" in
        jpg|jpeg|png) return 0 ;;
        *) return 1 ;;
    esac
}

has_native_sibling() {
    local input="$1"
    local dir="${input%/*}"
    local base="${input##*/}"
    local stem="${base%.*}"

    [ -f "$dir/$stem.jpg" ] || [ -f "$dir/$stem.jpeg" ] || [ -f "$dir/$stem.png" ]
}

# 壁紙ディレクトリから画像をランダムに選択
images=()
while IFS= read -r image; do
    ext="${image##*.}"
    ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
    if is_native_wallpaper "$ext" || ! has_native_sibling "$image"; then
        images+=("$image")
    fi
done < <(
    find "$WALLPAPER_DIR" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o \
           -iname '*.webp' -o -iname '*.gif' -o -iname '*.heic' -o \
           -iname '*.heif' -o -iname '*.tif' -o -iname '*.tiff' -o \
           -iname '*.bmp' -o -iname '*.avif' \) | sort
)

if [ ${#images[@]} -eq 0 ]; then
    echo "No images found in $WALLPAPER_DIR"
    exit 1
fi

# ランダムに1つ選択
source_image="${images[$RANDOM % ${#images[@]}]}"
random_image="$(prepare_wallpaper "$source_image")" || exit 1

# 設定ファイルの背景画像パスを更新
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|^background-image = .*|background-image = $random_image|" "$CONFIG_FILE"
else
    sed -i "s|^background-image = .*|background-image = $random_image|" "$CONFIG_FILE"
fi

echo "Selected wallpaper: $random_image"
