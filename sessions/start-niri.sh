#!/usr/bin/env bash
export XDG_CURRENT_DESKTOP=niri
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=niri

# Work around xcursor's XDG_DATA_HOME lookup not appending "icons/". This must
# be set here, before niri starts, so the compositor can find user-installed
# cursor themes; setting it in an interactive shell is too late.
export XCURSOR_PATH="$HOME/.local/share/icons:$HOME/.icons:/usr/share/icons:/usr/share/pixmaps"

exec niri-session
