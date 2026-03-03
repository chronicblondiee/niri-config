#!/usr/bin/env bash
# Clipboard manager using cliphist + rofi

case "$1" in
    d)
        # Delete mode
        cliphist list | rofi -dmenu -p "Delete entry" | cliphist delete
        ;;
    w)
        # Wipe all
        cliphist wipe
        ;;
    *)
        # Default: paste from history
        cliphist list | rofi -dmenu -p "Clipboard" | cliphist decode | wl-copy
        ;;
esac
