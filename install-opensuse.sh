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
    kitty
    fish
    nautilus
    wl-clipboard
    cliphist
    lxqt-openssh-askpass
    openssh
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
# Step 3a: Install zen-browser (flatpak)
# ─────────────────────────────────────────────

echo
info "Step 3a: Install zen-browser (Flatpak)"

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
else
    warn "flatpak not available, skipping zen-browser"
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

# Auto-detect monitor and replace __OUTPUT_BLOCK__ placeholder
if [[ "$NIRI_CONFIG_INSTALLED" == "true" ]] && grep -q '__OUTPUT_BLOCK__' "$NIRI_CONFIG_DIR/config.kdl"; then
    info "Detecting monitor output..."

    OUTPUT_NAME=""
    OUTPUT_MODE=""

    # Method 1: niri msg outputs (if niri is running)
    if command -v niri &>/dev/null && niri msg outputs &>/dev/null 2>&1; then
        OUTPUT_NAME=$(niri msg outputs 2>/dev/null | grep '^Output' | head -1 | awk '{print $2}' | tr -d '"')
        if [[ -n "$OUTPUT_NAME" ]]; then
            OUTPUT_MODE=$(niri msg outputs 2>/dev/null | grep -A5 "^Output \"$OUTPUT_NAME\"" | grep 'current mode' | grep -oP '\d+x\d+@[\d.]+')
        fi
    fi

    # Method 2: DRM sysfs fallback (works from TTY)
    if [[ -z "$OUTPUT_NAME" ]]; then
        for drm in /sys/class/drm/card*-*/; do
            if [[ "$(cat "$drm/status" 2>/dev/null)" == "connected" ]]; then
                OUTPUT_NAME=$(basename "$drm" | sed 's/^card[0-9]*-//')
                OUTPUT_MODE=$(head -1 "$drm/modes" 2>/dev/null | tr -s ' ' | xargs)
                if [[ -n "$OUTPUT_MODE" ]]; then
                    OUTPUT_MODE=$(echo "$OUTPUT_MODE" | awk '{print $1}')
                fi
                break
            fi
        done
    fi

    # GNU sed's s/// treats a raw embedded newline in the replacement as ending
    # the script ("unterminated `s' command"), so multi-line blocks are spliced
    # in with awk instead, which prints the replacement text verbatim.
    if [[ -n "$OUTPUT_NAME" ]]; then
        ok "Detected output: $OUTPUT_NAME${OUTPUT_MODE:+ ($OUTPUT_MODE)}"

        if [[ -n "$OUTPUT_MODE" ]]; then
            OUTPUT_BLOCK="output \"$OUTPUT_NAME\" {
    mode \"$OUTPUT_MODE\"
    scale 1.0
}"
        else
            OUTPUT_BLOCK="output \"$OUTPUT_NAME\" {
    scale 1.0
}"
        fi

        OUTPUT_BLOCK="$OUTPUT_BLOCK" awk '
            /^\/\/ __OUTPUT_BLOCK__/ { print ENVIRON["OUTPUT_BLOCK"]; next }
            { print }
        ' "$NIRI_CONFIG_DIR/config.kdl" > "$NIRI_CONFIG_DIR/config.kdl.tmp" \
            && mv "$NIRI_CONFIG_DIR/config.kdl.tmp" "$NIRI_CONFIG_DIR/config.kdl"
        ok "Output block configured for $OUTPUT_NAME"
    else
        warn "Could not detect monitor — leaving output placeholder"
        warn "Edit the output section in $NIRI_CONFIG_DIR/config.kdl manually"
        FALLBACK_BLOCK='// No output detected — uncomment and edit:
// output "DP-1" {
//     mode "1920x1080"
//     scale 1.0
// }'
        FALLBACK_BLOCK="$FALLBACK_BLOCK" awk '
            /^\/\/ __OUTPUT_BLOCK__/ { print ENVIRON["FALLBACK_BLOCK"]; next }
            { print }
        ' "$NIRI_CONFIG_DIR/config.kdl" > "$NIRI_CONFIG_DIR/config.kdl.tmp" \
            && mv "$NIRI_CONFIG_DIR/config.kdl.tmp" "$NIRI_CONFIG_DIR/config.kdl"
    fi
fi

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

if [[ -f "$PORTAL_CONF" ]]; then
    ok "Portal config already exists: $PORTAL_CONF"
else
    cat > "$PORTAL_CONF" <<'PORTAL_EOF'
[preferred]
default=gnome
org.freedesktop.impl.portal.Access=gnome
org.freedesktop.impl.portal.FileChooser=gnome
org.freedesktop.impl.portal.Screenshot=gnome
org.freedesktop.impl.portal.Screencast=gnome
PORTAL_EOF
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
# Step 4: Install session files
# ─────────────────────────────────────────────

echo
info "Step 4: Install session files"

mkdir -p "$HOME/.local/bin"
if [[ -f "$HOME/.local/bin/start-niri.sh" ]]; then
    ok "start-niri.sh already exists in ~/.local/bin/"
    if confirm "Overwrite?" "n"; then
        cp "$SCRIPT_DIR/sessions/start-niri.sh" "$HOME/.local/bin/start-niri.sh"
        chmod +x "$HOME/.local/bin/start-niri.sh"
        ok "start-niri.sh updated"
    fi
else
    cp "$SCRIPT_DIR/sessions/start-niri.sh" "$HOME/.local/bin/start-niri.sh"
    chmod +x "$HOME/.local/bin/start-niri.sh"
    ok "start-niri.sh installed to ~/.local/bin/"
fi

# The niri package ships its own /usr/share/wayland-sessions/niri.desktop pointing
# straight at niri-session; override it with the start-niri.sh wrapper so
# XDG_CURRENT_DESKTOP/XDG_SESSION_DESKTOP get set first. Re-applied on every run
# since a niri package upgrade can silently restore the packaged version.
SESSION_FILE="/usr/share/wayland-sessions/niri.desktop"
if [[ -f "$SESSION_FILE" ]] && grep -q "start-niri.sh" "$SESSION_FILE"; then
    ok "Session entry already points to start-niri.sh"
else
    if [[ -f "$SESSION_FILE" ]]; then
        info "Current session entry uses: $(grep '^Exec=' "$SESSION_FILE")"
    fi
    if confirm "Install/update $SESSION_FILE to use the start-niri.sh wrapper?" "y"; then
        sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/sessions/niri.desktop" | sudo tee "$SESSION_FILE" >/dev/null
        ok "SDDM session entry installed"
    else
        warn "Skipping SDDM session entry"
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
            sudo systemctl enable sddm.service
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
echo "  - GTK 3.0/4.0:    Dark theme + Adwaita cursor"
echo "  - Wallpapers:     $WALLPAPER_DIR/"
echo "  - Screenshots:    $HOME/Pictures/Screenshots/"
echo "  - Keyboard:       ie (console + X11/Wayland)"
echo "  - SSH agent:      systemd ssh-agent.socket + lxqt-openssh-askpass"
echo "  - XDG portal:     $PORTAL_CONF_DIR/niri-portals.conf"
echo "  - Session script: $HOME/.local/bin/start-niri.sh"
echo "  - SDDM entry:     /usr/share/wayland-sessions/niri.desktop"
echo
warn "A few keybinds were ported as best-effort guesses (not verified against a"
warn "running instance) — check these with 'noctalia msg --help' after logging in:"
echo "  - Mod+N (notification history), Mod+Ctrl+I (network panel),"
echo "    Mod+Ctrl+A (calendar), Mod+Shift+Space (emoji picker)"
echo
info "Next steps:"
echo "  1. Log out and select 'Niri' from the SDDM session picker"
echo "  2. Add wallpapers to $WALLPAPER_DIR/"
echo "  3. To customize monitor settings, edit the output section in:"
echo "     $NIRI_CONFIG_DIR/config.kdl (run 'niri msg outputs' for details)"
echo "  4. Open noctalia settings (Super+Comma) to customize the shell"
echo
