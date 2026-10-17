#!/usr/bin/env bash
set -euo pipefail
app="${1:-}"
case "$app" in
    ghostty) command_name=ghostty; app_command='~/.dotfiles/scripts/ubuntu-app-launch.sh ghostty'; pattern='' ;;
    chrome) command_name=google-chrome; app_command='~/.dotfiles/scripts/ubuntu-app-launch.sh chrome --new-window'; pattern='^(google-chrome|google-chrome-stable|chromium|chromium-browser)$' ;;
    vscode) command_name=code; app_command='~/.dotfiles/scripts/ubuntu-app-launch.sh vscode --new-window'; pattern='^(code|code-oss|code-url-handler|visual studio code|com.microsoft.vscode)$' ;;
    *) printf 'Usage: %s ghostty|chrome|vscode\n' "$0" >&2; exit 64 ;;
esac
workspace="$(hyprctl -j activeworkspace | jq -er '.id | select(type == "number" and . > 0)')"
if [ "$app" != ghostty ]; then
    address="$(hyprctl -j clients | jq -r --argjson workspace "$workspace" --arg pattern "$pattern" '
        [.[] | select(.workspace.id == $workspace)
         | select((.class // "" | ascii_downcase) | test($pattern)) | .address][0] // empty')"
    if [ -n "$address" ]; then
        exec hyprctl dispatch focuswindow "address:$address"
    fi
fi
if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Application not found: %s\n' "$command_name" >&2
    exit 127
fi
exec hyprctl dispatch exec "[workspace $workspace] $app_command"
