#!/usr/bin/env bash
# Install the official Linux binary after verifying the pinned release digest.
set -euo pipefail

if command -v cliamp >/dev/null 2>&1; then
    printf 'cliamp already installed: %s\n' "$(command -v cliamp)"
    exit 0
fi
if [ "$(uname -s)" != Linux ]; then
    printf 'Use brew install bjarneo/cliamp/cliamp on macOS.\n' >&2
    exit 1
fi

version=2.3.0
case "$(uname -m)" in
    x86_64|amd64)
        target=amd64
        checksum=5c59b5380c5165b473c06148c108ee60a18a1f9961f8013e38b4a68ed5def641
        ;;
    aarch64|arm64)
        target=arm64
        checksum=827b4aa879feecab33ea621dc1460c60ffa765c210b5046d679ce5a4073d2b32
        ;;
    *) printf 'Unsupported architecture for cliamp: %s\n' "$(uname -m)" >&2; exit 1 ;;
esac

temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
binary="$temporary/cliamp"
url="https://github.com/bjarneo/cliamp/releases/download/v$version/cliamp-linux-$target"
curl --fail --location --retry 2 --connect-timeout 15 --max-time 120 \
    "$url" --output "$binary"
if ! printf '%s  %s\n' "$checksum" "$binary" | sha256sum --check --status; then
    printf 'cliamp checksum verification failed.\n' >&2
    exit 1
fi
mkdir -p "$HOME/.local/bin"
install -m 755 "$binary" "$HOME/.local/bin/cliamp"
printf 'Installed cliamp %s in ~/.local/bin.\n' "$version"
