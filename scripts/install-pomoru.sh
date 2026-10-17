#!/usr/bin/env bash
# Build the pinned Pomoru release with local Lofi Station alerts.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
profile_dir="$repo_root/platforms/ubuntu/pomoru"
revision=8672d041bec1a3c80da95adbfb5d0f974a97f84b
if [ "$(uname -s)" != Linux ]; then
    printf 'This Pomoru build profile targets Linux.\n' >&2
    exit 1
fi
for dependency in curl patch sha256sum ffplay; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        printf 'Missing dependency: %s\n' "$dependency" >&2
        exit 1
    fi
done
cargo_bin="$(command -v cargo || true)"
if [ -z "$cargo_bin" ] && [ -x "$HOME/.cargo/bin/cargo" ]; then
    cargo_bin="$HOME/.cargo/bin/cargo"
fi
if [ -z "$cargo_bin" ]; then
    printf 'Install Rust/Cargo before building Pomoru.\n' >&2
    exit 1
fi

build_dir="$(mktemp -d)"
binary_temp=''
cleanup() {
    rm -rf "$build_dir"
    if [ -n "$binary_temp" ]; then rm -f "$binary_temp"; fi
}
trap cleanup EXIT
while read -r checksum relative; do
    mkdir -p "$build_dir/$(dirname "$relative")"
    curl --fail --silent --show-error --location --retry 2 \
        --connect-timeout 15 --max-time 120 \
        "https://raw.githubusercontent.com/RanXom/pomoru/$revision/$relative" \
        --output "$build_dir/$relative"
done < "$profile_dir/upstream.sha256"
(cd "$build_dir" && sha256sum --check "$profile_dir/upstream.sha256")
patch --batch --fuzz=0 -d "$build_dir" -p1 < "$profile_dir/alerts.patch"
cp "$profile_dir/alerts.rs" "$build_dir/src/pomo/alerts.rs"

export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/pomoru-build/target}"
"$cargo_bin" test --locked --manifest-path "$build_dir/Cargo.toml"
"$cargo_bin" build --release --locked --manifest-path "$build_dir/Cargo.toml"

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/pomoru"
mkdir -p "$config_dir/sounds" "$HOME/.local/bin"
for seed in config.toml alerts.toml; do
    if [ ! -e "$config_dir/$seed" ]; then
        cp "$profile_dir/$seed" "$config_dir/$seed"
    fi
done
install -m 644 "$profile_dir/sounds/warning-beep.mp3" "$config_dir/sounds/warning-beep.mp3"
install -m 644 "$profile_dir/sounds/timer-complete.mp3" "$config_dir/sounds/timer-complete.mp3"
if [ -e "$HOME/.local/bin/pomoru" ] && [ ! -e "$HOME/.local/bin/pomoru.upstream" ]; then
    cp -p "$HOME/.local/bin/pomoru" "$HOME/.local/bin/pomoru.upstream"
fi
binary_temp="$(mktemp "$HOME/.local/bin/.pomoru.XXXXXX")"
install -m 755 "$CARGO_TARGET_DIR/release/pomoru" "$binary_temp"
mv -f "$binary_temp" "$HOME/.local/bin/pomoru"
printf 'Installed Pomoru with warning and completion sounds. Restart any running Pomoru.\n'
