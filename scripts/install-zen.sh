#!/usr/bin/env bash
# Install the official Zen Browser tarball after verifying the pinned release
# digest. The user-writable install keeps Zen's built-in updater working.
set -euo pipefail

if [ "$(uname -s)" != Linux ]; then
    printf 'Use brew install --cask zen on macOS.\n' >&2
    exit 1
fi

prefix="$HOME/.local/opt/zen"
if [ -f "$prefix/zen" ] && [ -x "$prefix/zen" ]; then
    printf 'Zen Browser already installed: %s\n' "$prefix"
elif [ -e "$prefix" ]; then
    printf 'Incomplete Zen Browser install at %s; remove it and rerun.\n' "$prefix" >&2
    exit 1
else
    version=1.23.4b
    case "$(uname -m)" in
        x86_64|amd64)
            target=x86_64
            checksum=ba81dd70af70d645f2f0a692f7fa4510f819290abfd8d8e60273d3d5a60d0536
            ;;
        aarch64|arm64)
            target=aarch64
            checksum=75142191e0ad3380e485a39a3737b502e69cf30368fbb516b80e7e6f0b0f3a5f
            ;;
        *) printf 'Unsupported architecture for Zen Browser: %s\n' "$(uname -m)" >&2; exit 1 ;;
    esac

    # Stage beside the target so the final mv is an atomic rename.
    mkdir -p "$(dirname "$prefix")"
    temporary="$(mktemp -d "$(dirname "$prefix")/.zen.XXXXXX")"
    trap 'rm -rf "$temporary"' EXIT
    archive="$temporary/zen.tar.xz"
    url="https://github.com/zen-browser/desktop/releases/download/$version/zen.linux-$target.tar.xz"
    curl --fail --location --retry 2 --connect-timeout 15 --max-time 600 \
        "$url" --output "$archive"
    if ! printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check --status; then
        printf 'Zen Browser checksum verification failed.\n' >&2
        exit 1
    fi
    tar -xJf "$archive" -C "$temporary"
    mv "$temporary/zen" "$prefix"
    printf 'Installed Zen Browser %s in %s.\n' "$version" "$prefix"
fi

mkdir -p "$HOME/.local/bin"
ln -sfn "$prefix/zen" "$HOME/.local/bin/zen"

# Desktop entries need absolute paths, so generate this one per machine.
applications_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$applications_dir"
cat > "$applications_dir/zen.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Zen Browser
Exec=$prefix/zen %u
Icon=$prefix/browser/chrome/icons/default/default128.png
Terminal=false
Categories=Network;WebBrowser;
MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
StartupWMClass=zen
StartupNotify=true
EOF
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$applications_dir"
fi
