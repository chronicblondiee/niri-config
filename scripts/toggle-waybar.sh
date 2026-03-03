#!/usr/bin/env bash
# Toggle waybar visibility

STATE_FILE="$HOME/.config/niri/waybar-disabled"

if [ -f "$STATE_FILE" ]; then
    rm "$STATE_FILE"
    ~/.config/waybar/launch.sh &
else
    touch "$STATE_FILE"
    killall waybar 2>/dev/null
fi
