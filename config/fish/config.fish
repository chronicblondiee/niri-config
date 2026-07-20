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
