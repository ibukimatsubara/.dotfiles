#!/bin/bash
# Prepare the focused tile for the next window, using its longest edge.
# CoreGraphics is available through macOS's built-in JavaScript for Automation.
set -u
export PATH="${PATH}:/opt/homebrew/bin:/usr/local/bin"

command -v aerospace >/dev/null 2>&1 || exit 0
IFS='|' read -r window_id layout fullscreen < <(
    aerospace list-windows --focused \
        --format '%{window-id}|%{window-layout}|%{window-is-fullscreen}' 2>/dev/null
)
case "${window_id:-}" in ''|*[!0-9]*) exit 0 ;; esac
case "${layout:-}" in h_tiles|v_tiles) ;; *) exit 0 ;; esac
[[ "${fullscreen:-}" == false ]] || exit 0

direction=$(osascript -l JavaScript - "$window_id" <<'JXA'
ObjC.import('CoreGraphics');
function run(argv) {
    var windows = ObjC.deepUnwrap(ObjC.castRefToObject(
        $.CGWindowListCopyWindowInfo(1, 0)
    ));
    for (var i = 0; i < windows.length; i++) {
        var window = windows[i];
        if (String(window.kCGWindowNumber) !== argv[0]) continue;
        var bounds = window.kCGWindowBounds;
        if (!(bounds.Width > 0 && bounds.Height > 0)) return '';
        return bounds.Width >= bounds.Height ? 'horizontal' : 'vertical';
    }
    return '';
}
JXA
) || exit 0
case "$direction" in horizontal|vertical) ;; *) exit 0 ;; esac

# A newer callback owns the new focus. Never split a tile with stale geometry.
focused_id=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null)
[[ "$focused_id" == "$window_id" ]] || exit 0
aerospace split --window-id "$window_id" "$direction"
