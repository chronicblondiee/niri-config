#!/usr/bin/env bash
#
# Niri Standalone Installer — openSUSE Tumbleweed
# Ports the niri + Noctalia v5 desktop to openSUSE Tumbleweed/Slowroll
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIRI_CONFIG_DIR="$HOME/.config/niri"
NOCTALIA_CONFIG_DIR="$HOME/.config/noctalia"
KITTY_CONFIG_DIR="$HOME/.config/kitty"
FISH_CONFIG_DIR="$HOME/.config/fish"
GTK3_CONFIG_DIR="$HOME/.config/gtk-3.0"
GTK4_CONFIG_DIR="$HOME/.config/gtk-4.0"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

NOCTALIA_REPO_URL="https://download.opensuse.org/repositories/home:neifua:Noctalia/openSUSE_Tumbleweed/home:neifua:Noctalia.repo"
KDE_FRAMEWORKS_REPO_URL="https://download.opensuse.org/repositories/KDE:Frameworks/openSUSE_Tumbleweed/KDE:Frameworks.repo"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}::${NC} $1"; }
ok()    { echo -e "${GREEN}::${NC} $1"; }
warn()  { echo -e "${YELLOW}::${NC} $1"; }
err()   { echo -e "${RED}::${NC} $1"; }

confirm() {
    local prompt="$1"
    local default="${2:-y}"
    if [[ "$default" == "y" ]]; then
        read -rp "$(echo -e "${BLUE}::${NC} ${prompt} [Y/n] ")" answer
        [[ -z "$answer" || "$answer" =~ ^[Yy] ]]
    else
        read -rp "$(echo -e "${BLUE}::${NC} ${prompt} [y/N] ")" answer
        [[ "$answer" =~ ^[Yy] ]]
    fi
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local bak="${file}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$file" "$bak"
        info "Backed up $file -> $bak"
    fi
}

pkg_installed() { rpm -q "$1" &>/dev/null; }

repo_added() { zypper lr 2>/dev/null | grep -qi "$1"; }

# ─────────────────────────────────────────────
# Step 1: Check prerequisites
# ─────────────────────────────────────────────

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Niri Standalone Installer (openSUSE)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

info "Checking prerequisites..."

if ! command -v zypper &>/dev/null; then
    err "zypper not found. This installer requires openSUSE Tumbleweed or Slowroll."
    exit 1
fi
ok "openSUSE (zypper) system detected"

if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    case "${VERSION_ID:-}${NAME:-}" in
        *Tumbleweed*|*Slowroll*) ok "Detected $NAME" ;;
        *)
            warn "Detected $NAME — Noctalia v5 requires sdbus-c++ >= 2.x, only shipped on Tumbleweed/Slowroll"
            if ! confirm "Continue anyway?" "n"; then
                exit 1
            fi
            ;;
    esac
fi

# ─────────────────────────────────────────────
# Step 1b: Clean up broken symlinks in ~/.config
# ─────────────────────────────────────────────

echo
info "Step 1b: Clean up broken symlinks in ~/.config"

BROKEN_LINKS=()
while IFS= read -r -d '' link; do
    BROKEN_LINKS+=("$link")
done < <(find "$HOME/.config" -maxdepth 3 -type l ! -exec test -e {} \; -print0 2>/dev/null)

if [[ ${#BROKEN_LINKS[@]} -eq 0 ]]; then
    ok "No broken symlinks found"
else
    echo "  Found ${#BROKEN_LINKS[@]} broken symlink(s):"
    for link in "${BROKEN_LINKS[@]}"; do
        target=$(readlink "$link" 2>/dev/null || echo "unknown")
        echo -e "    ${YELLOW}${link}${NC} -> ${target}"
    done
    echo
    if confirm "Remove broken symlinks?"; then
        for link in "${BROKEN_LINKS[@]}"; do
            rm "$link"
        done
        ok "Broken symlinks removed"
    else
        warn "Keeping broken symlinks"
    fi
fi

# ─────────────────────────────────────────────
# Step 2: Add required repositories
# ─────────────────────────────────────────────

echo
info "Step 2: Add required repositories"

if repo_added "neifua"; then
    ok "Noctalia OBS repo already added"
else
    if confirm "Add Noctalia v5 OBS repo ($NOCTALIA_REPO_URL)?"; then
        sudo zypper --non-interactive addrepo --refresh "$NOCTALIA_REPO_URL"
        sudo zypper --gpg-auto-import-keys refresh
        ok "Noctalia OBS repo added"
    else
        err "Cannot install noctalia without its OBS repo"
        exit 1
    fi
fi

# ─────────────────────────────────────────────
# Step 3: Install packages
# ─────────────────────────────────────────────

echo
info "Step 3: Install packages"

ZYPPER_PACKAGES=(
    niri
    xwayland-satellite
    xdg-desktop-portal-gnome
    xdg-desktop-portal-gtk
    gnome-keyring
    kitty
    fish
    nautilus
    wl-clipboard
    cliphist
    lxqt-openssh-askpass
    openssh
    gamemode
    gamemoded
    libgamemode0-32bit
    libgamemodeauto0-32bit
    gamescope
)
MISSING=()
for pkg in "${ZYPPER_PACKAGES[@]}"; do
    pkg_installed "$pkg" || MISSING+=("$pkg")
done

if [[ ${#MISSING[@]} -eq 0 ]]; then
    ok "All official packages already installed: ${ZYPPER_PACKAGES[*]}"
else
    info "Packages to install: ${MISSING[*]}"
    if confirm "Install with zypper?"; then
        sudo zypper install -y "${MISSING[@]}"
        ok "Official packages installed"
    else
        warn "Skipping official package installation"
    fi
fi

# GameMode's privileged governor/priority controls use the package-created group.
GAMEMODE_USER="${SUDO_USER:-$USER}"
if getent group gamemode &>/dev/null; then
    if id -nG "$GAMEMODE_USER" | tr ' ' '\n' | grep -qx gamemode; then
        ok "$GAMEMODE_USER is already in the gamemode group"
    elif confirm "Add $GAMEMODE_USER to the gamemode group for governor/priority controls?"; then
        sudo usermod -aG gamemode "$GAMEMODE_USER"
        warn "GameMode group membership will take effect after a fresh login"
    else
        warn "Skipping gamemode group membership — some governor/priority controls may be unavailable"
    fi
fi

# polkit-kde-agent-6: try bare install, fall back to KDE:Frameworks repo
if pkg_installed polkit-kde-agent-6; then
    ok "polkit-kde-agent-6 already installed"
else
    if confirm "Install polkit-kde-agent-6?"; then
        if ! sudo zypper install -y polkit-kde-agent-6 2>/dev/null; then
            warn "Not found in enabled repos — adding KDE:Frameworks"
            if ! repo_added "KDE:Frameworks"; then
                sudo zypper --non-interactive addrepo --refresh "$KDE_FRAMEWORKS_REPO_URL"
                sudo zypper --gpg-auto-import-keys refresh
            fi
            sudo zypper install -y polkit-kde-agent-6
        fi
        ok "polkit-kde-agent-6 installed"
    else
        warn "Skipping polkit-kde-agent-6 — polkit prompts won't have a GUI agent"
    fi
fi

# Noctalia v5 shell (not noctalia-qs, which is the unrelated v4 Quickshell fork)
if pkg_installed noctalia; then
    ok "noctalia already installed"
else
    if confirm "Install noctalia (v5 shell)?"; then
        sudo zypper install -y noctalia
        ok "noctalia installed"
    else
        warn "Skipping noctalia — bar/notifications/wallpaper/lock screen won't be available"
    fi
fi

# ─────────────────────────────────────────────
# Step 3a: Install Flatpak applications
# ─────────────────────────────────────────────

echo
info "Step 3a: Install Flatpak applications"

if ! command -v flatpak &>/dev/null; then
    if confirm "Install flatpak?"; then
        sudo zypper install -y flatpak
    fi
fi

if command -v flatpak &>/dev/null; then
    # --user scope: avoids the polkit "Deploy" authorization system-wide
    # installs need, which has no agent to grant it from a plain terminal/SSH session
    if ! flatpak remote-list --user 2>/dev/null | grep -q flathub; then
        if confirm "Add Flathub remote (user scope)?"; then
            flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo
        fi
    fi
    if flatpak list --user 2>/dev/null | grep -q app.zen_browser.zen; then
        ok "zen-browser already installed"
    else
        if confirm "Install zen-browser via Flatpak (user scope)?"; then
            flatpak install -y --user flathub app.zen_browser.zen
            ok "zen-browser installed"
        else
            warn "Skipping zen-browser — Mod+B will need a different browser"
        fi
    fi

    if flatpak list --user 2>/dev/null | grep -q dev.vencord.Vesktop; then
        ok "Vesktop already installed"
    else
        if confirm "Install Vesktop via Flatpak (user scope)?"; then
            flatpak install -y --user flathub dev.vencord.Vesktop
            ok "Vesktop installed"
        else
            warn "Skipping Vesktop — Discord screen sharing may not work on niri"
        fi
    fi

    if flatpak list --user 2>/dev/null | grep -q dev.vencord.Vesktop; then
        # Vesktop defaults to X11 when it is available. Denying both X11
        # sockets makes the Flatpak use its native Wayland backend.
        flatpak override --user --nosocket=x11 --nosocket=fallback-x11 dev.vencord.Vesktop
        ok "Vesktop configured for native Wayland"
    fi
else
    warn "flatpak not available, skipping zen-browser and Vesktop"
fi

# ─────────────────────────────────────────────
# Step 3b: Install Catppuccin SDDM theme
# ─────────────────────────────────────────────

echo
info "Step 3b: Install Catppuccin SDDM theme"

CATPPUCCIN_THEME_DIR="/usr/share/sddm/themes/catppuccin-mocha-mauve"
CATPPUCCIN_ZIP_URL="https://github.com/catppuccin/sddm/releases/latest/download/catppuccin-mocha-mauve-sddm.zip"
if [[ -d "$CATPPUCCIN_THEME_DIR" ]]; then
    ok "Catppuccin SDDM theme already installed"
else
    if confirm "Install Catppuccin Mocha SDDM theme (downloads from GitHub releases)?"; then
        if ! command -v unzip &>/dev/null; then
            sudo zypper install -y unzip
        fi
        TMP_THEME_DIR=$(mktemp -d)
        if curl -sL -o "$TMP_THEME_DIR/theme.zip" "$CATPPUCCIN_ZIP_URL" \
            && unzip -q "$TMP_THEME_DIR/theme.zip" -d "$TMP_THEME_DIR"; then
            if [[ -d "$TMP_THEME_DIR/catppuccin-mocha-mauve" ]]; then
                # sddm isn't installed until Step 4a, so /usr/share/sddm/themes/
                # may not exist yet — create it regardless of step order
                sudo mkdir -p /usr/share/sddm/themes
                sudo cp -r "$TMP_THEME_DIR/catppuccin-mocha-mauve" /usr/share/sddm/themes/
                ok "Catppuccin SDDM theme installed"
            else
                warn "Unexpected zip layout — inspect $TMP_THEME_DIR manually"
            fi
        else
            warn "Failed to download/extract theme zip — install manually from https://github.com/catppuccin/sddm/releases"
        fi
        rm -rf "$TMP_THEME_DIR"
    else
        warn "Skipping SDDM theme — login screen will use the default theme"
    fi
fi

# ─────────────────────────────────────────────
# Step 3c: Install niri config
# ─────────────────────────────────────────────

echo
info "Step 3c: Install niri config"

mkdir -p "$NIRI_CONFIG_DIR"

NIRI_CONFIG_INSTALLED=false
if [[ -f "$NIRI_CONFIG_DIR/config.kdl" ]]; then
    ok "Niri config already exists at $NIRI_CONFIG_DIR/config.kdl"
    if confirm "Overwrite with repo version?" "n"; then
        backup_file "$NIRI_CONFIG_DIR/config.kdl"
        cp "$SCRIPT_DIR/config/niri/config.kdl" "$NIRI_CONFIG_DIR/config.kdl"
        NIRI_CONFIG_INSTALLED=true
        ok "Niri config updated"
    else
        warn "Keeping existing niri config"
    fi
else
    cp "$SCRIPT_DIR/config/niri/config.kdl" "$NIRI_CONFIG_DIR/config.kdl"
    NIRI_CONFIG_INSTALLED=true
    ok "Niri config installed to $NIRI_CONFIG_DIR/config.kdl"
fi

# The output block in config/niri/config.kdl is hardcoded for this specific
# two-monitor hardware (Acer VG270U P on DP-2, Gigabyte MO34WQC2 on DP-1) —
# no auto-detection needed since it's the same fixed hardware on every
# install (see CLAUDE.md). If you swap monitors or ports, edit the `output`
# blocks in $NIRI_CONFIG_DIR/config.kdl manually and check `niri msg outputs`
# for the exact connector names/refresh rates.

# ─────────────────────────────────────────────
# Step 3d: Install noctalia config
# ─────────────────────────────────────────────

echo
info "Step 3d: Install noctalia config"

mkdir -p "$NOCTALIA_CONFIG_DIR"

if [[ -f "$NOCTALIA_CONFIG_DIR/config.toml" ]]; then
    ok "Noctalia config already exists at $NOCTALIA_CONFIG_DIR/config.toml"
    if confirm "Overwrite with repo version?" "n"; then
        backup_file "$NOCTALIA_CONFIG_DIR/config.toml"
        sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/config/noctalia/config.toml" > "$NOCTALIA_CONFIG_DIR/config.toml"
        ok "Noctalia config updated"
    else
        warn "Keeping existing noctalia config"
    fi
else
    sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/config/noctalia/config.toml" > "$NOCTALIA_CONFIG_DIR/config.toml"
    ok "Noctalia config installed to $NOCTALIA_CONFIG_DIR/config.toml"
fi

# ─────────────────────────────────────────────
# Step 3e: Install kitty config
# ─────────────────────────────────────────────

echo
info "Step 3e: Install kitty config"

mkdir -p "$KITTY_CONFIG_DIR"

if [[ -f "$KITTY_CONFIG_DIR/kitty.conf" ]]; then
    ok "Kitty config already exists at $KITTY_CONFIG_DIR/kitty.conf"
    if confirm "Overwrite with repo version?" "n"; then
        backup_file "$KITTY_CONFIG_DIR/kitty.conf"
        cp "$SCRIPT_DIR/config/kitty/kitty.conf" "$KITTY_CONFIG_DIR/kitty.conf"
        ok "Kitty config updated"
    else
        warn "Keeping existing kitty config"
    fi
else
    cp "$SCRIPT_DIR/config/kitty/kitty.conf" "$KITTY_CONFIG_DIR/kitty.conf"
    ok "Kitty config installed to $KITTY_CONFIG_DIR/kitty.conf"
fi

# ─────────────────────────────────────────────
# Step 3f: Install fish config
# ─────────────────────────────────────────────

echo
info "Step 3f: Install fish config"

mkdir -p "$FISH_CONFIG_DIR"

if [[ -f "$FISH_CONFIG_DIR/config.fish" ]]; then
    ok "Fish config already exists at $FISH_CONFIG_DIR/config.fish"
    if confirm "Overwrite with repo version?" "n"; then
        backup_file "$FISH_CONFIG_DIR/config.fish"
        cp "$SCRIPT_DIR/config/fish/config.fish" "$FISH_CONFIG_DIR/config.fish"
        ok "Fish config updated"
    else
        warn "Keeping existing fish config"
    fi
else
    cp "$SCRIPT_DIR/config/fish/config.fish" "$FISH_CONFIG_DIR/config.fish"
    ok "Fish config installed to $FISH_CONFIG_DIR/config.fish"
fi

# ─────────────────────────────────────────────
# Step 3g: Install GTK configs
# ─────────────────────────────────────────────

echo
info "Step 3g: Install GTK configs (dark theme)"

for gtk_ver in 3.0 4.0; do
    dest_dir="$HOME/.config/gtk-${gtk_ver}"
    mkdir -p "$dest_dir"
    if [[ -f "$dest_dir/settings.ini" ]]; then
        ok "GTK ${gtk_ver} config already exists"
        if confirm "Overwrite GTK ${gtk_ver} config?" "n"; then
            backup_file "$dest_dir/settings.ini"
            cp "$SCRIPT_DIR/config/gtk-${gtk_ver}/settings.ini" "$dest_dir/settings.ini"
            ok "GTK ${gtk_ver} config updated"
        else
            warn "Keeping existing GTK ${gtk_ver} config"
        fi
    else
        cp "$SCRIPT_DIR/config/gtk-${gtk_ver}/settings.ini" "$dest_dir/settings.ini"
        ok "GTK ${gtk_ver} config installed"
    fi
done

# ─────────────────────────────────────────────
# Step 3g2: Install Catppuccin cursor theme
# ─────────────────────────────────────────────

echo
info "Step 3g2: Install Catppuccin cursor theme"

CURSOR_THEME_NAME="catppuccin-mocha-mauve-cursors"
CURSOR_THEME_DIR="$HOME/.local/share/icons/$CURSOR_THEME_NAME"
CURSOR_ZIP_URL="https://github.com/catppuccin/cursors/releases/latest/download/${CURSOR_THEME_NAME}.zip"
if [[ -d "$CURSOR_THEME_DIR" ]]; then
    ok "Catppuccin cursor theme already installed"
else
    if confirm "Install Catppuccin Mocha Mauve cursor theme (downloads from GitHub releases)?"; then
        if ! command -v unzip &>/dev/null; then
            sudo zypper install -y unzip
        fi
        TMP_CURSOR_DIR=$(mktemp -d)
        if curl -sL -o "$TMP_CURSOR_DIR/theme.zip" "$CURSOR_ZIP_URL" \
            && unzip -q "$TMP_CURSOR_DIR/theme.zip" -d "$TMP_CURSOR_DIR"; then
            if [[ -d "$TMP_CURSOR_DIR/$CURSOR_THEME_NAME" ]]; then
                mkdir -p "$HOME/.local/share/icons"
                cp -r "$TMP_CURSOR_DIR/$CURSOR_THEME_NAME" "$HOME/.local/share/icons/"
                ok "Catppuccin cursor theme installed to $CURSOR_THEME_DIR"
            else
                warn "Unexpected zip layout — inspect $TMP_CURSOR_DIR manually"
            fi
        else
            warn "Failed to download/extract cursor zip — install manually from https://github.com/catppuccin/cursors/releases"
        fi
        rm -rf "$TMP_CURSOR_DIR"
    else
        warn "Skipping cursor theme — config.kdl/GTK settings reference it, so the default theme will show until it's installed"
    fi
fi

# xdg-desktop-portal-gnome (this repo's portal backend) reports cursor
# theme/size to portal-aware GTK/Qt apps via the org.gnome.desktop.interface
# GSettings schema — niri's own `cursor` block and gtk-3.0/4.0 settings.ini
# don't reach those apps at all, so without this they'd keep showing
# Adwaita/24 regardless of everything else being configured correctly.
if command -v gsettings &>/dev/null; then
    current_cursor_theme=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null)
    if [[ "$current_cursor_theme" == "'$CURSOR_THEME_NAME'" ]]; then
        ok "GSettings cursor theme already set to $CURSOR_THEME_NAME"
    else
        gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME_NAME"
        gsettings set org.gnome.desktop.interface cursor-size 18
        ok "GSettings cursor theme/size updated (portal-aware apps will now match)"
    fi
fi

# Same portal gap as above, but for dark mode: GTK 3.0/4.0 settings.ini sets
# gtk-application-prefer-dark-theme=1/gtk-theme-name=Adwaita-dark, but that's
# invisible to GTK4/libadwaita apps and modern Qt6 apps, which read dark-mode
# state from the org.freedesktop.appearance portal setting instead — which
# xdg-desktop-portal-gnome backs with these same GSettings keys, not the local
# settings.ini files. Without this, GTK4/Qt6 apps and portal-aware browsers
# (e.g. zen-browser/Firefox) can render light even though everything else here
# is dark.
if command -v gsettings &>/dev/null; then
    current_color_scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)
    if [[ "$current_color_scheme" == "'prefer-dark'" ]]; then
        ok "GSettings color scheme already set to prefer-dark"
    else
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
        ok "GSettings dark mode enabled (portal-aware GTK4/Qt6 apps will now match)"
    fi
fi

# ─────────────────────────────────────────────
# Step 3h: Create wallpaper/screenshot directories
# ─────────────────────────────────────────────

echo
info "Step 3h: Create wallpaper/screenshot directories"

if [[ -d "$WALLPAPER_DIR" ]]; then
    ok "Wallpaper directory already exists: $WALLPAPER_DIR"
else
    mkdir -p "$WALLPAPER_DIR"
    ok "Created $WALLPAPER_DIR"
    info "Add wallpaper images to this directory for noctalia to use"
fi

SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
if [[ -d "$SCREENSHOT_DIR" ]]; then
    ok "Screenshots directory already exists: $SCREENSHOT_DIR"
else
    mkdir -p "$SCREENSHOT_DIR"
    ok "Created $SCREENSHOT_DIR"
fi

# ─────────────────────────────────────────────
# Step 3i: Set keyboard layout (Ireland)
# ─────────────────────────────────────────────

echo
info "Step 3i: Set system keyboard layout to Ireland (ie)"

if command -v localectl &>/dev/null; then
    CURRENT_X11_LAYOUT=$(localectl status 2>/dev/null | grep 'X11 Layout' | sed 's/.*: *//')
    if [[ "$CURRENT_X11_LAYOUT" == "ie" ]]; then
        ok "System keyboard layout already set to ie"
    else
        info "Current X11 layout: ${CURRENT_X11_LAYOUT:-unset}"
        if confirm "Set system keyboard layout (console + X11/Wayland) to Ireland (ie)?"; then
            sudo localectl set-x11-keymap ie
            sudo localectl set-keymap ie
            ok "System keyboard layout set to ie"
        else
            warn "Keeping current system keyboard layout"
        fi
    fi
else
    warn "localectl not found, skipping system keyboard layout"
fi

# ─────────────────────────────────────────────
# Step 3j: Enable SSH agent
# ─────────────────────────────────────────────

echo
info "Step 3j: Enable SSH agent (systemd socket + lxqt-openssh-askpass)"

# Unlike Arch, openSUSE's openssh package ships no ssh-agent.socket/service
# user units — install the upstream Arch unit files ourselves if missing
SSH_AGENT_UNIT_DIR="$HOME/.config/systemd/user"
if [[ ! -f "$SSH_AGENT_UNIT_DIR/ssh-agent.socket" ]]; then
    mkdir -p "$SSH_AGENT_UNIT_DIR"
    cat > "$SSH_AGENT_UNIT_DIR/ssh-agent.socket" <<'EOF'
[Unit]
ConditionEnvironment=!SSH_AGENT_PID
Description=Socket for the OpenSSH key agent
Documentation=man:ssh-agent(1)

[Socket]
ListenStream=%t/ssh-agent.socket
RemoveOnStop=yes

[Install]
WantedBy=sockets.target
EOF
    cat > "$SSH_AGENT_UNIT_DIR/ssh-agent.service" <<'EOF'
[Unit]
ConditionEnvironment=!SSH_AGENT_PID
Description=OpenSSH key agent
Documentation=man:ssh-agent(1) man:ssh-add(1) man:ssh(1)
Requires=ssh-agent.socket

[Service]
ExecStart=/usr/bin/ssh-agent -D
SuccessExitStatus=2
Type=simple

[Install]
Also=ssh-agent.socket
EOF
    systemctl --user daemon-reload
    ok "Installed ssh-agent.socket/service user units to $SSH_AGENT_UNIT_DIR"
fi

if systemctl --user is-enabled ssh-agent.socket &>/dev/null 2>&1; then
    ok "ssh-agent.socket already enabled"
else
    if confirm "Enable systemd ssh-agent.socket?"; then
        systemctl --user enable ssh-agent.socket
        systemctl --user start ssh-agent.socket
        ok "ssh-agent.socket enabled and started"
    else
        warn "Skipping SSH agent setup — you'll need to manage SSH keys manually"
    fi
fi

if systemctl --user is-enabled gcr-ssh-agent.socket &>/dev/null 2>&1; then
    info "gcr-ssh-agent.socket is enabled — it conflicts with systemd ssh-agent"
    if confirm "Disable gcr-ssh-agent.socket?"; then
        systemctl --user disable gcr-ssh-agent.socket
        systemctl --user stop gcr-ssh-agent.socket 2>/dev/null || true
        ok "gcr-ssh-agent.socket disabled"
    fi
fi

# ─────────────────────────────────────────────
# Step 3k: Disable conflicting services
# ─────────────────────────────────────────────

echo
info "Step 3k: Disable conflicting services"

CONFLICTING_NOTIF=(swaync dunst mako)
found_conflict=false
for svc in "${CONFLICTING_NOTIF[@]}"; do
    if systemctl --user is-active "$svc" &>/dev/null; then
        info "$svc is running — it conflicts with noctalia's notification server"
        if confirm "Stop and mask $svc?"; then
            systemctl --user stop "$svc"
            systemctl --user mask "$svc"
            ok "$svc stopped and masked"
        else
            warn "$svc left running — noctalia notifications may not work"
        fi
        found_conflict=true
    elif systemctl --user is-enabled "$svc" &>/dev/null 2>&1; then
        info "$svc is enabled but not running"
        if confirm "Mask $svc to prevent it from starting?"; then
            systemctl --user mask "$svc"
            ok "$svc masked"
        else
            warn "$svc left enabled — it may conflict with noctalia notifications"
        fi
        found_conflict=true
    fi
done

CONFLICTING_SSH_AGENTS=(gnome-keyring-ssh.service gnome-keyring-daemon.service kwalletd5.service kwalletd6.service)
for svc in "${CONFLICTING_SSH_AGENTS[@]}"; do
    if systemctl --user is-enabled "$svc" &>/dev/null 2>&1; then
        info "$svc is enabled — it may conflict with systemd ssh-agent"
        if confirm "Disable $svc?"; then
            systemctl --user disable "$svc"
            systemctl --user stop "$svc" 2>/dev/null || true
            ok "$svc disabled"
        else
            warn "$svc left enabled — may conflict with ssh-agent.socket"
        fi
        found_conflict=true
    fi
done

if [[ "$found_conflict" == "false" ]]; then
    ok "No conflicting services found"
fi

# ─────────────────────────────────────────────
# Step 3l: Configure XDG desktop portal
# ─────────────────────────────────────────────

echo
info "Step 3l: Configure XDG desktop portal for niri"

PORTAL_CONF_DIR="$HOME/.config/xdg-desktop-portal"
PORTAL_CONF="$PORTAL_CONF_DIR/niri-portals.conf"
mkdir -p "$PORTAL_CONF_DIR"

CONFLICTING_PORTALS=()
for pkg in xdg-desktop-portal-hyprland xdg-desktop-portal-wlr; do
    if pkg_installed "$pkg"; then
        CONFLICTING_PORTALS+=("$pkg")
    fi
done

if [[ ${#CONFLICTING_PORTALS[@]} -gt 0 ]]; then
    warn "Found conflicting portal backend(s): ${CONFLICTING_PORTALS[*]}"
    if confirm "Remove conflicting portal packages?"; then
        sudo zypper remove -y "${CONFLICTING_PORTALS[@]}"
        ok "Conflicting portals removed"
    else
        warn "Conflicting portals left installed — screen sharing may not work correctly"
    fi
fi

PORTAL_CONFIG_CONTENT=$(cat <<'PORTAL_EOF'
[preferred]
default=gnome;gtk;
org.freedesktop.impl.portal.Access=gtk;
org.freedesktop.impl.portal.Notification=gtk;
org.freedesktop.impl.portal.Secret=gnome-keyring;
PORTAL_EOF
)

if [[ -f "$PORTAL_CONF" ]]; then
    if [[ "$(cat "$PORTAL_CONF")" == "$PORTAL_CONFIG_CONTENT" ]]; then
        ok "Portal config is current: $PORTAL_CONF"
    elif confirm "Replace outdated portal config with the current niri defaults?" "y"; then
        backup_file "$PORTAL_CONF"
        printf '%s\n' "$PORTAL_CONFIG_CONTENT" > "$PORTAL_CONF"
        ok "Portal config updated"
    else
        warn "Keeping existing portal config — screen sharing may not work correctly"
    fi
else
    printf '%s\n' "$PORTAL_CONFIG_CONTENT" > "$PORTAL_CONF"
    ok "Portal config installed: $PORTAL_CONF"
fi

# ─────────────────────────────────────────────
# Step 3m: Set fish as default shell
# ─────────────────────────────────────────────

echo
info "Step 3m: Default shell"

FISH_PATH=$(command -v fish 2>/dev/null || echo "/usr/bin/fish")

if ! grep -qx "$FISH_PATH" /etc/shells 2>/dev/null; then
    if confirm "Add $FISH_PATH to /etc/shells (required by chsh)?"; then
        echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
        ok "$FISH_PATH added to /etc/shells"
    fi
fi

CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)

if [[ "$CURRENT_SHELL" == "$FISH_PATH" ]]; then
    ok "Fish is already the default shell"
else
    info "Current default shell: $CURRENT_SHELL"
    if confirm "Set fish as your default shell?"; then
        chsh -s "$FISH_PATH"
        ok "Default shell changed to fish (effective on next login)"
    else
        warn "Keeping $CURRENT_SHELL as default shell"
    fi
fi

# ─────────────────────────────────────────────
# Step 4: Install session environment
# ─────────────────────────────────────────────

echo
info "Step 4: Install session environment"

# The packaged /usr/share/wayland-sessions/niri.desktop launches niri-session
# directly, which starts niri as a systemd user service. environment.d is read
# by the systemd user manager, so anything set here reaches niri no matter which
# session entry started it — and unlike a file under /usr, zypper can never
# overwrite it. (This repo used to ship a start-niri.sh wrapper installed over
# the packaged niri.desktop; that file isn't marked %config, so every niri
# update silently reverted it and took the XCURSOR_PATH fix with it.)
ENV_D_DIR="$HOME/.config/environment.d"
ENV_D_CONF="$ENV_D_DIR/10-niri-cursor.conf"
ENV_D_CONTENT=$(sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/config/environment.d/10-niri-cursor.conf")

mkdir -p "$ENV_D_DIR"
if [[ -f "$ENV_D_CONF" ]]; then
    if [[ "$(cat "$ENV_D_CONF")" == "$ENV_D_CONTENT" ]]; then
        ok "Session environment is current: $ENV_D_CONF"
    elif confirm "Replace outdated session environment config?" "y"; then
        backup_file "$ENV_D_CONF"
        printf '%s\n' "$ENV_D_CONTENT" > "$ENV_D_CONF"
        ok "Session environment updated (effective next login)"
    else
        warn "Keeping existing $ENV_D_CONF — the cursor theme may not load"
    fi
else
    printf '%s\n' "$ENV_D_CONTENT" > "$ENV_D_CONF"
    ok "Session environment installed: $ENV_D_CONF (effective next login)"
fi

# Clean up the retired wrapper from earlier versions of this installer.
SESSION_FILE="/usr/share/wayland-sessions/niri.desktop"
if [[ -f "$SESSION_FILE" ]] && grep -q "start-niri.sh" "$SESSION_FILE"; then
    warn "$SESSION_FILE still points at the retired start-niri.sh wrapper"
    if confirm "Restore the packaged niri session entry?" "y"; then
        sudo zypper install -f -y niri
        ok "Packaged session entry restored"
    else
        warn "Leaving the wrapper entry in place — it must exist or login will fail"
    fi
fi

if [[ -f "$HOME/.local/bin/start-niri.sh" ]] \
    && ! grep -q "start-niri.sh" "$SESSION_FILE" 2>/dev/null; then
    if confirm "Remove the now-unused $HOME/.local/bin/start-niri.sh?" "y"; then
        rm -f "$HOME/.local/bin/start-niri.sh"
        ok "Retired session wrapper removed"
    fi
fi

# ─────────────────────────────────────────────
# Step 4a: Install and configure SDDM
# ─────────────────────────────────────────────

echo
info "Step 4a: Install and configure SDDM"

SDDM_PKG=""
if pkg_installed sddm-qt6; then
    SDDM_PKG="sddm-qt6"
elif pkg_installed sddm; then
    SDDM_PKG="sddm"
fi

if [[ -n "$SDDM_PKG" ]]; then
    ok "$SDDM_PKG already installed"
else
    if confirm "Install SDDM display manager?"; then
        if sudo zypper install -y sddm-qt6 2>/dev/null; then
            SDDM_PKG="sddm-qt6"
        else
            sudo zypper install -y sddm
            SDDM_PKG="sddm"
        fi
        ok "$SDDM_PKG installed"
    else
        warn "Skipping SDDM — you'll need another display manager to select the niri session"
    fi
fi

if [[ -n "$SDDM_PKG" ]]; then
    if systemctl is-enabled sddm &>/dev/null 2>&1; then
        ok "sddm.service already enabled"
    else
        if confirm "Enable sddm.service and set graphical.target as default?"; then
            # openSUSE preseeds /etc/systemd/system/display-manager.service as a
            # symlink to display-manager-legacy.service on minimal installs with
            # no DM chosen yet; --force lets sddm's alias replace it
            sudo systemctl enable --force sddm.service
            sudo systemctl set-default graphical.target
            ok "sddm.service enabled, graphical.target set as default"
        else
            warn "Skipping display manager enablement"
        fi
    fi

    SDDM_THEME_CONF="/etc/sddm.conf.d/10-theme.conf"
    if [[ -f "$SDDM_THEME_CONF" ]] && grep -q "Current=catppuccin-mocha-mauve" "$SDDM_THEME_CONF"; then
        ok "SDDM theme already configured (Catppuccin Mocha)"
    else
        if confirm "Set SDDM theme to Catppuccin Mocha?"; then
            sudo mkdir -p /etc/sddm.conf.d
            printf '[Theme]\nCurrent=catppuccin-mocha-mauve\n' | sudo tee "$SDDM_THEME_CONF" >/dev/null
            ok "SDDM theme configured (Catppuccin Mocha)"
        else
            warn "Skipping SDDM theme configuration"
        fi
    fi

    # openSUSE's minimal-X pattern already logged in once with icewm (or
    # whatever xsession it preselects) before this installer ever ran, so
    # sddm's ~sddm/state.conf remembers that as the [Last] session and keeps
    # preselecting/relaunching it on every reboot even after niri.desktop is
    # installed — the user has to notice and manually switch the session in
    # the login dropdown, or they land right back in the old desktop. Force
    # niri as the remembered session so a plain login boots straight into it.
    SDDM_STATE_CONF="/var/lib/sddm/state.conf"
    if sudo test -f "$SDDM_STATE_CONF" && sudo grep -q "^Session=niri.desktop$" "$SDDM_STATE_CONF" 2>/dev/null; then
        ok "SDDM default session already set to niri"
    else
        if confirm "Set niri as the default SDDM session (fixes reboot landing back on the distro's default desktop)?" "y"; then
            if sudo test -f "$SDDM_STATE_CONF"; then
                sudo cp "$SDDM_STATE_CONF" "${SDDM_STATE_CONF}.bak.$(date +%Y%m%d%H%M%S)"
            fi
            printf '[Last]\nSession=niri.desktop\nUser=%s\n' "$USER" | sudo tee "$SDDM_STATE_CONF" >/dev/null
            sudo chown sddm:sddm "$SDDM_STATE_CONF" 2>/dev/null || true
            ok "SDDM default session set to niri"
        else
            warn "Skipping default session — you'll need to pick 'Niri' manually at the login screen"
        fi
    fi
fi

# ─────────────────────────────────────────────
# Step 5: Validate
# ─────────────────────────────────────────────

echo
info "Step 5: Validate niri config"

if command -v niri &>/dev/null; then
    if niri validate 2>&1; then
        ok "Niri config validation passed"
    else
        err "Niri config validation failed — check $NIRI_CONFIG_DIR/config.kdl"
    fi
else
    warn "niri not installed, skipping validation"
fi

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installation Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
info "What was set up:"
echo "  - Niri config:    $NIRI_CONFIG_DIR/config.kdl"
echo "  - Noctalia shell: $NOCTALIA_CONFIG_DIR/config.toml (v5)"
echo "  - Kitty terminal: $KITTY_CONFIG_DIR/kitty.conf"
echo "  - Fish shell:     $FISH_CONFIG_DIR/config.fish"
echo "  - GTK 3.0/4.0:    Dark theme + Catppuccin Mocha Mauve cursor"
echo "  - Wallpapers:     $WALLPAPER_DIR/"
echo "  - Screenshots:    $HOME/Pictures/Screenshots/"
echo "  - Keyboard:       ie (console + X11/Wayland)"
echo "  - SSH agent:      systemd ssh-agent.socket + lxqt-openssh-askpass"
echo "  - XDG portal:     $PORTAL_CONF_DIR/niri-portals.conf"
echo "  - Session env:    $ENV_D_CONF (XCURSOR_PATH)"
echo "  - SDDM entry:     /usr/share/wayland-sessions/niri.desktop (packaged)"
echo "  - SDDM default:   niri.desktop preselected (/var/lib/sddm/state.conf)"
echo
warn "A few keybinds were ported as best-effort guesses (not verified against a"
warn "running instance) — check these with 'noctalia msg --help' after logging in:"
echo "  - Mod+N (notification history), Mod+Ctrl+I (network panel),"
echo "    Mod+Ctrl+A (calendar), Mod+Shift+Space (emoji picker)"
echo
info "Next steps:"
echo "  1. Reboot — SDDM should now boot straight into Niri. If it still lands"
echo "     on the old desktop, pick 'Niri' from the session picker manually once"
echo "     (bottom-left icon on the login screen) and it'll stick from then on."
echo "  2. Add wallpapers to $WALLPAPER_DIR/"
echo "  3. To customize monitor settings, edit the output section in:"
echo "     $NIRI_CONFIG_DIR/config.kdl (run 'niri msg outputs' for details)"
echo "  4. Open noctalia settings (Super+Comma) to customize the shell"
echo
