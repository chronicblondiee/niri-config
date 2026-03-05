#!/usr/bin/env bash
# Niri-native power actions (used by wlogout)

case "$1" in
    lock)
        qs -c noctalia-shell ipc call lockscreen lock
        ;;
    exit)
        niri msg action quit
        ;;
    suspend)
        systemctl suspend
        ;;
    hibernate)
        systemctl hibernate
        ;;
    reboot)
        systemctl reboot
        ;;
    shutdown)
        systemctl poweroff
        ;;
    *)
        echo "Usage: $0 {lock|exit|suspend|hibernate|reboot|shutdown}"
        exit 1
        ;;
esac
