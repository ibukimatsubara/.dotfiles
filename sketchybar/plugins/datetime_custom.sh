#!/bin/bash

if [ "$NAME" = "clock" ]; then
  # Time format: 15:30
  TIME=$(date '+%H:%M')
  sketchybar --set clock label="$TIME"
elif [ "$NAME" = "date" ]; then
  # Date format: 1月13日(月)
  DATE=$(date '+%-m月%-d日(%a)')
  sketchybar --set date label="$DATE"
fi