#!/bin/sh

muted="$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)"

if [ "$muted" = "true" ]; then
    osascript -e 'set volume without output muted' >/dev/null
else
    osascript -e 'set volume with output muted' >/dev/null
fi
