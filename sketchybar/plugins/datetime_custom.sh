#!/bin/bash

# Combined date and time format: 09/13 Fri 15:30
DATETIME=$(date '+%m/%d %a %H:%M')
sketchybar --set datetime label="$DATETIME"