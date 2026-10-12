#!/bin/sh

cores="$(sysctl -n hw.ncpu 2>/dev/null)"
usage="$(ps -A -o %cpu= | awk -v cores="${cores:-1}" '
    { total += $1 }
    END {
        if (cores > 0) printf "%.0f", total / cores
        else print "0"
    }
')"

sketchybar --set "$NAME" label="${usage:-0}%"
