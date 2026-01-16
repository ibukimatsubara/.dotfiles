#!/bin/bash

# Tailscale VPN Status Item
tailscale=(
  script="$PLUGIN_DIR/tailscale.sh"
  update_freq=30
  icon.font="JetBrainsMono Nerd Font:Regular:14"
  icon="󰦝"
  icon.padding_left=8
  icon.padding_right=8
  label.drawing=off
  background.corner_radius=0
  background.drawing=on
  click_script="$PLUGIN_DIR/tailscale_toggle.sh"
)

sketchybar --add item tailscale center \
           --set tailscale "${tailscale[@]}"
