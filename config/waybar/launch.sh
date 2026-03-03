#!/usr/bin/env bash
# Standalone niri waybar launcher

exec 200>/tmp/waybar-launch.lock
flock -n 200 || exit 0

killall waybar 2>/dev/null
sleep 0.5

WAYBAR_DIR="$HOME/.config/waybar"

if [ -f "$HOME/.config/niri/waybar-disabled" ]; then
    echo ":: Waybar disabled"
    flock -u 200
    exec 200>&-
    exit 0
fi

config_file="$WAYBAR_DIR/config"
style_file="$WAYBAR_DIR/style.css"

# Allow user overrides
[ -f "$WAYBAR_DIR/config-custom" ] && config_file="$WAYBAR_DIR/config-custom"
[ -f "$WAYBAR_DIR/style-custom.css" ] && style_file="$WAYBAR_DIR/style-custom.css"

waybar -c "$config_file" -s "$style_file" &

flock -u 200
exec 200>&-
