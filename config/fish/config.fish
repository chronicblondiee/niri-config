# Fish shell config

# PATH
fish_add_path ~/.local/bin

# Aliases
alias ls='ls --color=auto'
alias ll='ls -la'
alias la='ls -A'
alias grep='grep --color=auto'

# Disable greeting
set -g fish_greeting

# Set default editor
if command -q nvim
    set -gx EDITOR nvim
    set -gx VISUAL nvim
    alias vim='nvim'
end

# SSH agent (systemd ssh-agent.socket + lxqt-openssh-askpass for GUI prompt)
set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
set -gx SSH_ASKPASS /usr/bin/lxqt-openssh-askpass
set -gx SSH_ASKPASS_REQUIRE prefer

# Wayland env vars
set -gx MOZ_ENABLE_WAYLAND 1
set -gx QT_QPA_PLATFORM wayland
set -gx GDK_BACKEND wayland

# Cursor theme lookup path — works around a bug in the `xcursor` crate niri
# uses (v0.3.10): when $XDG_DATA_HOME is set (as it is here), the crate
# searches that path directly instead of appending "icons/", so themes in
# ~/.local/share/icons/ are never found. Setting XCURSOR_PATH explicitly
# bypasses that broken fallback entirely (it's checked first, before the
# buggy XDG_DATA_HOME logic).
set -gx XCURSOR_PATH "$HOME/.local/share/icons:$HOME/.icons:/usr/share/icons:/usr/share/pixmaps"
