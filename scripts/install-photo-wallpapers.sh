#!/bin/bash

set -euo pipefail

wallpaper_dir="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers/codex}"
source_dir="$wallpaper_dir/sources"

print_info() {
    printf '\033[34m%s\033[0m\n' "$1"
}

print_success() {
    printf '\033[32m✓ %s\033[0m\n' "$1"
}

print_error() {
    printf '\033[31m✗ %s\033[0m\n' "$1" >&2
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        print_error "Required command not found: $1"
        exit 1
    fi
}

download_source() {
    local name="$1"
    local url="$2"
    local destination="$source_dir/$name.jpg"
    local temporary_file

    if [ -s "$destination" ]; then
        print_success "Source already downloaded: $name"
        return
    fi

    temporary_file="$(mktemp "$source_dir/.${name}.XXXXXX")"
    print_info "Downloading $name"

    if ! curl --fail --location --silent --show-error \
        --retry 3 --connect-timeout 15 \
        "$url" -o "$temporary_file"; then
        rm -f "$temporary_file"
        print_error "Download failed: $name"
        exit 1
    fi

    mv "$temporary_file" "$destination"
    print_success "Downloaded $name"
}

render_variant() {
    local source_file="$1"
    local name="$2"
    local suffix="$3"
    local target_width="$4"
    local target_height="$5"
    local dimensions
    local source_width
    local source_height
    local crop_width
    local crop_height
    local work_dir
    local output_file="$wallpaper_dir/$name-$suffix.png"

    dimensions="$(sips -g pixelWidth -g pixelHeight "$source_file" 2>/dev/null \
        | awk '/pixelWidth/{width=$2} /pixelHeight/{height=$2} END{print width, height}')"
    read -r source_width source_height <<< "$dimensions"

    if [ -z "${source_width:-}" ] || [ -z "${source_height:-}" ]; then
        print_error "Could not read image dimensions: $source_file"
        exit 1
    fi

    if (( source_width * target_height > source_height * target_width )); then
        crop_height="$source_height"
        crop_width="$((source_height * target_width / target_height))"
    else
        crop_width="$source_width"
        crop_height="$((source_width * target_height / target_width))"
    fi

    if (( crop_width < target_width || crop_height < target_height )); then
        print_error "Refusing to upscale $name for ${target_width}x${target_height}"
        exit 1
    fi

    work_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-wallpaper.XXXXXX")"
    sips --cropToHeightWidth "$crop_height" "$crop_width" \
        "$source_file" --out "$work_dir/cropped.jpg" >/dev/null
    sips --resampleHeightWidth "$target_height" "$target_width" \
        -s format png "$work_dir/cropped.jpg" \
        --out "$work_dir/rendered.png" >/dev/null

    mv "$work_dir/rendered.png" "$output_file"
    rm -f "$work_dir/cropped.jpg"
    rmdir "$work_dir"
    print_success "Rendered $(basename "$output_file")"
}

render_pair() {
    local name="$1"
    local source_file="$2"

    render_variant "$source_file" "$name" qhd 3440 1440
    render_variant "$source_file" "$name" macbook 3456 2234
}

require_command curl
require_command sips
mkdir -p "$source_dir"

# Elias Tigiser — Pexels photo 14786072
download_source \
    pexels-14786072-elias-tigiser \
    'https://images.pexels.com/photos/14786072/pexels-photo-14786072.jpeg'
alpine_panorama_source="$source_dir/pexels-14786072-elias-tigiser.jpg"

# Kyle Glenn — Unsplash photo 0JJzYdoq62c
download_source \
    unsplash-0JJzYdoq62c-kyle-glenn \
    'https://images.unsplash.com/photo-1502298771545-937cd94b0f48?fm=jpg&q=95'
rio_grande_source="$source_dir/unsplash-0JJzYdoq62c-kyle-glenn.jpg"

render_pair alpine-lake-panorama "$alpine_panorama_source"
render_pair rio-grande-sunset "$rio_grande_source"

print_success "Photo wallpapers installed in $wallpaper_dir"
