#!/bin/sh

app_key="${1:-}"
open_mode="${2:-focus-or-open}"

case "$open_mode" in
    focus-or-open|new-window) ;;
    *) exit 64 ;;
esac

case "$app_key" in
    ghostty)
        bundle_id="com.mitchellh.ghostty"
        ;;
    chrome)
        bundle_id="com.google.Chrome"
        ;;
    vscode)
        bundle_id="com.microsoft.VSCode"
        ;;
    *)
        exit 64
        ;;
esac

if [ "$open_mode" != "new-window" ] && command -v aerospace >/dev/null 2>&1; then
    focused_workspace="$(aerospace list-workspaces --focused 2>/dev/null)"

    if [ -n "$focused_workspace" ]; then
        window_id="$(
            aerospace list-windows \
                --workspace "$focused_workspace" \
                --app-bundle-id "$bundle_id" \
                --format '%{window-id}' 2>/dev/null | head -n 1
        )"

        if [ -n "$window_id" ]; then
            if aerospace focus --window-id "$window_id"; then
                exit 0
            fi
        fi
    fi
fi

case "$app_key" in
    ghostty)
        if pgrep -x ghostty >/dev/null 2>&1; then
            osascript <<'APPLESCRIPT'
tell application id "com.mitchellh.ghostty"
    set created_window to new window
    activate window created_window
end tell
APPLESCRIPT
        else
            open -a "Ghostty.app"
        fi
        ;;
    chrome)
        osascript -e 'tell application "Google Chrome" to make new window'
        ;;
    vscode)
        "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" --new-window
        ;;
esac
