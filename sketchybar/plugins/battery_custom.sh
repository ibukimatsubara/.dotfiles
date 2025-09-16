#!/bin/bash

PERCENTAGE=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
CHARGING=$(pmset -g batt | grep 'AC Power')

# Hide when battery is 100% and charging (AC Power connected)
if [ $PERCENTAGE -eq 100 ] && [ ! -z "$CHARGING" ]; then
  sketchybar --set battery drawing=off
  exit 0
fi

# Show battery for all other cases
sketchybar --set battery drawing=on

# Color based on battery level
if [ $PERCENTAGE -gt 70 ]; then
  COLOR=0xffff79c6  # Pink
  ICON="󰁹"  # Full battery (Nerd Font)
elif [ $PERCENTAGE -gt 40 ]; then
  COLOR=0xfff1fa8c  # Yellow
  ICON="󰂀"  # Half battery (Nerd Font)
elif [ $PERCENTAGE -gt 20 ]; then
  COLOR=0xffffb86c  # Orange
  ICON="󰁻"  # Low battery (Nerd Font)
else
  COLOR=0xffff5555  # Red
  ICON="󰁺"  # Very low battery (Nerd Font)
fi

# Charging indicator
if [ ! -z "$CHARGING" ]; then
  ICON="󰂄"  # Charging icon (Nerd Font)
  COLOR=0xffff79c6  # Pink when charging
fi

sketchybar --set battery \
  icon="$ICON" \
  icon.color=$COLOR \
  label="${PERCENTAGE}%" \
  background.color=0x33$(echo $COLOR | cut -c 5-)