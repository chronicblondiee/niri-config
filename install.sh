#!/usr/bin/env bash
#
# Niri Standalone Installer
# Sets up niri as a standalone compositor on Arch Linux
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


# ─────────────────────────────────────────────
# Step 1: Check prerequisites
# ─────────────────────────────────────────────

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Niri Standalone Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

info "Checking prerequisites..."

if ! command -v pacman &>/dev/null; then
    err "pacman not found. This installer requires Arch Linux or a derivative."
    exit 1
fi
ok "Arch-based system detected"

# ─────────────────────────────────────────────
# Step 1b: Detect old compositor setups
# ─────────────────────────────────────────────

echo
info "Step 1b: Check for existing compositor setups"

OLD_COMPOSITORS=()
for pkg in hyprland sway; do
    if pacman -Qi "$pkg" &>/dev/null; then
        OLD_COMPOSITORS+=("$pkg")
    fi
done

if [[ ${#OLD_COMPOSITORS[@]} -gt 0 ]]; then
    warn "Found existing compositor(s): ${OLD_COMPOSITORS[*]}"
    info "These may have conflicting configs, services, and packages"
    if [[ -f "$SCRIPT_DIR/cleanup.sh" ]]; then
        if confirm "Run cleanup.sh first to remove old Hyprland/ML4W dependencies?" "n"; then
            bash "$SCRIPT_DIR/cleanup.sh"
            echo
            info "Continuing with installation..."
        else
            warn "Skipping cleanup — conflicts may need manual resolution"
        fi
    fi
else
    ok "No conflicting compositors found"
fi

# ─────────────────────────────────────────────
# Step 1c: Clean up broken symlinks in ~/.config
# ─────────────────────────────────────────────

echo
info "Step 1c: Clean up broken symlinks in ~/.config"

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
# Step 2: Install packages
# ─────────────────────────────────────────────

echo
info "Step 2: Install packages"

PACMAN_PACKAGES=(
    niri
    xwayland-satellite
    xdg-desktop-portal-gnome
    qt6-svg
    qt6-declarative
    kitty
    fish
    nautilus
    wl-clipboard
    cliphist
    polkit-kde-agent
    lxqt-openssh-askpass
    openssh
)
AUR_PACKAGES=(noctalia-shell catppuccin-sddm-theme-mocha zen-browser-bin)
MISSING_PACMAN=()
MISSING_AUR=()

for pkg in "${PACMAN_PACKAGES[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        MISSING_PACMAN+=("$pkg")
    fi
done

for pkg in "${AUR_PACKAGES[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        MISSING_AUR+=("$pkg")
    fi
done

if [[ ${#MISSING_PACMAN[@]} -eq 0 ]]; then
    ok "All official packages already installed: ${PACMAN_PACKAGES[*]}"
else
    info "Official packages to install: ${MISSING_PACMAN[*]}"
    if confirm "Install with pacman?"; then
        sudo pacman -S --needed "${MISSING_PACMAN[@]}"
        ok "Official packages installed"
    else
        warn "Skipping official package installation"
    fi
fi

if [[ ${#MISSING_AUR[@]} -eq 0 ]]; then
    ok "All AUR packages already installed: ${AUR_PACKAGES[*]}"
else
    # Find an AUR helper
    AUR_HELPER=""
    for helper in paru yay; do
        if command -v "$helper" &>/dev/null; then
            AUR_HELPER="$helper"
            break
        fi
    done

    if [[ -z "$AUR_HELPER" ]]; then
        err "No AUR helper found (paru or yay). Install one first, then install: ${MISSING_AUR[*]}"
    else
        info "AUR packages to install (via $AUR_HELPER): ${MISSING_AUR[*]}"
        if confirm "Install with $AUR_HELPER?"; then
            "$AUR_HELPER" -S --needed "${MISSING_AUR[@]}"
            ok "AUR packages installed"
        else
            warn "Skipping AUR package installation"
        fi
    fi
fi

# ─────────────────────────────────────────────
# Step 3: Copy niri config
# ─────────────────────────────────────────────

echo
info "Step 3: Install niri config"

mkdir -p "$NIRI_CONFIG_DIR"

if [[ -f "$NIRI_CONFIG_DIR/config.kdl" ]]; then
    ok "Niri config already exists at $NIRI_CONFIG_DIR/config.kdl"
    if confirm "Overwrite with repo version?" "n"; then
        backup_file "$NIRI_CONFIG_DIR/config.kdl"
        cp "$SCRIPT_DIR/config/niri/config.kdl" "$NIRI_CONFIG_DIR/config.kdl"
        ok "Niri config updated"
    else
        warn "Keeping existing niri config"
    fi
else
    cp "$SCRIPT_DIR/config/niri/config.kdl" "$NIRI_CONFIG_DIR/config.kdl"
    ok "Niri config installed to $NIRI_CONFIG_DIR/config.kdl"
fi

# ─────────────────────────────────────────────
# Step 3a: Install noctalia-shell config
# ─────────────────────────────────────────────

echo
info "Step 3a: Install noctalia-shell config"

mkdir -p "$NOCTALIA_CONFIG_DIR"

if [[ -f "$NOCTALIA_CONFIG_DIR/settings.json" ]]; then
    ok "Noctalia config already exists at $NOCTALIA_CONFIG_DIR/settings.json"
    if confirm "Overwrite with repo version?" "n"; then
        backup_file "$NOCTALIA_CONFIG_DIR/settings.json"
        sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/config/noctalia/settings.json" > "$NOCTALIA_CONFIG_DIR/settings.json"
        ok "Noctalia config updated"
    else
        warn "Keeping existing noctalia config"
    fi
else
    sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/config/noctalia/settings.json" > "$NOCTALIA_CONFIG_DIR/settings.json"
    ok "Noctalia config installed to $NOCTALIA_CONFIG_DIR/settings.json"
fi

# ─────────────────────────────────────────────
# Step 3b: Install kitty config
# ─────────────────────────────────────────────

echo
info "Step 3b: Install kitty config"

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
# Step 3c: Install fish config
# ─────────────────────────────────────────────

echo
info "Step 3c: Install fish config"

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
# Step 3d: Install GTK configs
# ─────────────────────────────────────────────

echo
info "Step 3d: Install GTK configs (dark theme)"

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
# Step 3e: Create wallpaper directory
# ─────────────────────────────────────────────

echo
info "Step 3e: Create wallpaper directory"

if [[ -d "$WALLPAPER_DIR" ]]; then
    ok "Wallpaper directory already exists: $WALLPAPER_DIR"
else
    mkdir -p "$WALLPAPER_DIR"
    ok "Created $WALLPAPER_DIR"
    info "Add wallpaper images to this directory for noctalia to use"
fi

# Screenshots directory
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
if [[ -d "$SCREENSHOT_DIR" ]]; then
    ok "Screenshots directory already exists: $SCREENSHOT_DIR"
else
    mkdir -p "$SCREENSHOT_DIR"
    ok "Created $SCREENSHOT_DIR"
fi

# ─────────────────────────────────────────────
# Step 3f: Enable SSH agent
# ─────────────────────────────────────────────

echo
info "Step 3f: Enable SSH agent (systemd socket + lxqt-openssh-askpass)"

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

# Disable gcr-ssh-agent if active (conflicts with systemd ssh-agent)
if systemctl --user is-enabled gcr-ssh-agent.socket &>/dev/null 2>&1; then
    info "gcr-ssh-agent.socket is enabled — it conflicts with systemd ssh-agent"
    if confirm "Disable gcr-ssh-agent.socket?"; then
        systemctl --user disable gcr-ssh-agent.socket
        systemctl --user stop gcr-ssh-agent.socket 2>/dev/null || true
        ok "gcr-ssh-agent.socket disabled"
    fi
fi

# ─────────────────────────────────────────────
# Step 3g: Disable conflicting services
# ─────────────────────────────────────────────

echo
info "Step 3g: Disable conflicting services"

# Notification daemons that conflict with noctalia's built-in notification server
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

# Other SSH agents that conflict with systemd ssh-agent
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
# Step 3h: Configure XDG desktop portal
# ─────────────────────────────────────────────

echo
info "Step 3h: Configure XDG desktop portal for niri"

PORTAL_CONF_DIR="$HOME/.config/xdg-desktop-portal"
PORTAL_CONF="$PORTAL_CONF_DIR/niri-portals.conf"
mkdir -p "$PORTAL_CONF_DIR"

# Check for conflicting portals
CONFLICTING_PORTALS=()
for pkg in xdg-desktop-portal-hyprland xdg-desktop-portal-wlr; do
    if pacman -Qi "$pkg" &>/dev/null; then
        CONFLICTING_PORTALS+=("$pkg")
    fi
done

if [[ ${#CONFLICTING_PORTALS[@]} -gt 0 ]]; then
    warn "Found conflicting portal backend(s): ${CONFLICTING_PORTALS[*]}"
    if confirm "Remove conflicting portal packages?"; then
        sudo pacman -Rns "${CONFLICTING_PORTALS[@]}"
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
# Step 3i: Set fish as default shell
# ─────────────────────────────────────────────

echo
info "Step 3i: Default shell"

CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
FISH_PATH=$(command -v fish 2>/dev/null || echo "/usr/bin/fish")

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

# Install start-niri.sh
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

# Install SDDM session entry
SESSION_FILE="/usr/share/wayland-sessions/niri.desktop"
if [[ -f "$SESSION_FILE" ]]; then
    ok "SDDM session entry already exists"
    if grep -q "start-niri.sh" "$SESSION_FILE"; then
        ok "Session entry already points to start-niri.sh"
    else
        info "Current session entry uses: $(grep '^Exec=' "$SESSION_FILE")"
        if confirm "Update to use start-niri.sh wrapper?" "y"; then
            sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/sessions/niri.desktop" | sudo tee "$SESSION_FILE" >/dev/null
            ok "SDDM session entry updated"
        fi
    fi
else
    info "Installing SDDM session entry (requires sudo)"
    if confirm "Install $SESSION_FILE?"; then
        sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/sessions/niri.desktop" | sudo tee "$SESSION_FILE" >/dev/null
        ok "SDDM session entry installed"
    else
        warn "Skipping SDDM session entry"
    fi
fi

# Configure SDDM theme
SDDM_CONF="/etc/sddm.conf"
SDDM_NEEDS_UPDATE=false

if [[ -f "$SDDM_CONF" ]]; then
    if ! grep -q "Current=catppuccin-mocha-mauve" "$SDDM_CONF"; then
        SDDM_NEEDS_UPDATE=true
    fi
else
    SDDM_NEEDS_UPDATE=true
fi

if [[ "$SDDM_NEEDS_UPDATE" == "true" ]]; then
    info "SDDM Catppuccin theme (requires sudo)"
    if confirm "Set SDDM theme to Catppuccin Mocha?"; then
        if [[ -f "$SDDM_CONF" ]]; then
            # Preserve existing config, just update/add the theme line
            if grep -q '^\[Theme\]' "$SDDM_CONF"; then
                sudo sed -i '/^\[Theme\]/,/^\[/{s/^Current=.*/Current=catppuccin-mocha-mauve/}' "$SDDM_CONF"
                # If no Current= existed under [Theme], add it
                if ! grep -q 'Current=catppuccin-mocha-mauve' "$SDDM_CONF"; then
                    sudo sed -i '/^\[Theme\]/a Current=catppuccin-mocha-mauve' "$SDDM_CONF"
                fi
            else
                printf '\n[Theme]\nCurrent=catppuccin-mocha-mauve\n' | sudo tee -a "$SDDM_CONF" >/dev/null
            fi
        else
            printf '[Theme]\nCurrent=catppuccin-mocha-mauve\n' | sudo tee "$SDDM_CONF" >/dev/null
        fi
        ok "SDDM theme configured (Catppuccin Mocha)"
    else
        warn "Skipping SDDM theme configuration"
    fi
else
    ok "SDDM theme already configured (Catppuccin Mocha)"
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
echo "  - Noctalia shell: $NOCTALIA_CONFIG_DIR/settings.json"
echo "  - Kitty terminal: $KITTY_CONFIG_DIR/kitty.conf"
echo "  - Fish shell:     $FISH_CONFIG_DIR/config.fish"
echo "  - GTK 3.0/4.0:    Dark theme + Adwaita cursor"
echo "  - Wallpapers:     $WALLPAPER_DIR/"
echo "  - Screenshots:    $HOME/Pictures/Screenshots/"
echo "  - SSH agent:      systemd ssh-agent.socket + lxqt-openssh-askpass"
echo "  - XDG portal:    $PORTAL_CONF_DIR/niri-portals.conf"
echo "  - Session script: $HOME/.local/bin/start-niri.sh"
echo "  - SDDM entry:    /usr/share/wayland-sessions/niri.desktop"
echo
info "Noctalia-shell provides:"
echo "  - Status bar (top, with workspaces, clock, tray, etc.)"
echo "  - Notifications (top-right)"
echo "  - Wallpaper manager (~/Pictures/Wallpapers/)"
echo "  - Lock screen (idle: 5min lock, 10min screen off)"
echo "  - OSD (volume, brightness)"
echo "  - Control center (right-click bar)"
echo "  - Settings panel (Super+Comma)"
echo
info "Next steps:"
echo "  1. Log out and select 'Niri' from the SDDM session picker"
echo "  2. Add wallpapers to $WALLPAPER_DIR/"
echo "  3. To customize monitor settings, edit the output section in:"
echo "     $NIRI_CONFIG_DIR/config.kdl (run 'niri msg outputs' for details)"
echo "  4. Open noctalia settings (Super+Comma) to customize the shell"
echo
