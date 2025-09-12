#!/bin/bash

if [ "$NAME" = "clock" ]; then
  # Time format: 15:30
  TIME=$(date '+%H:%M')
  sketchybar --set clock label="$TIME"
elif [ "$NAME" = "date" ]; then
  # Date format: 09/13 Fri
  DATE=$(date '+%m/%d %a')
  sketchybar --set date label="$DATE"
fi