#!/usr/bin/env bash
#
# Niri Dual-Compositor Installer
# Sets up niri alongside an existing Hyprland + ML4W installation
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYBAR_DIR="$HOME/.config/waybar"
NIRI_CONFIG_DIR="$HOME/.config/niri"

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
echo "  Niri Dual-Compositor Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

info "Checking prerequisites..."

# Check Arch-based
if ! command -v pacman &>/dev/null; then
    err "pacman not found. This installer requires Arch Linux or a derivative."
    exit 1
fi
ok "Arch-based system detected"

# Check Hyprland
if ! command -v Hyprland &>/dev/null; then
    warn "Hyprland not found. This installer is designed to work alongside Hyprland."
    if ! confirm "Continue anyway?" "n"; then
        exit 1
    fi
else
    ok "Hyprland found"
fi

# Check ML4W
if [[ -d "$HOME/.config/ml4w" ]]; then
    ok "ML4W dotfiles found"
else
    warn "ML4W dotfiles not found at ~/.config/ml4w"
    warn "Waybar integration assumes ML4W directory structure."
    if ! confirm "Continue anyway?" "n"; then
        exit 1
    fi
fi

# ─────────────────────────────────────────────
# Step 2: Install packages
# ─────────────────────────────────────────────

echo
info "Step 2: Install packages"

PACKAGES=(niri swayidle swaylock xwayland-satellite)
MISSING=()

for pkg in "${PACKAGES[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        MISSING+=("$pkg")
    fi
done

if [[ ${#MISSING[@]} -eq 0 ]]; then
    ok "All packages already installed: ${PACKAGES[*]}"
else
    info "Packages to install: ${MISSING[*]}"
    if confirm "Install with pacman?"; then
        sudo pacman -S --needed "${MISSING[@]}"
        ok "Packages installed"
    else
        warn "Skipping package installation"
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
    # Check if it points to our start script
    if grep -q "start-niri.sh" "$SESSION_FILE"; then
        ok "Session entry already points to start-niri.sh"
    else
        info "Current session entry uses: $(grep '^Exec=' "$SESSION_FILE")"
        if confirm "Update to use start-niri.sh wrapper?" "y"; then
            # Generate desktop entry with correct home path
            sed "s|/home/brown|$HOME|g" "$SCRIPT_DIR/sessions/niri.desktop" | sudo tee "$SESSION_FILE" >/dev/null
            ok "SDDM session entry updated"
        fi
    fi
else
    info "Installing SDDM session entry (requires sudo)"
    if confirm "Install $SESSION_FILE?"; then
        sed "s|/home/brown|$HOME|g" "$SCRIPT_DIR/sessions/niri.desktop" | sudo tee "$SESSION_FILE" >/dev/null
        ok "SDDM session entry installed"
    else
        warn "Skipping SDDM session entry"
    fi
fi

# ─────────────────────────────────────────────
# Step 5: Patch waybar
# ─────────────────────────────────────────────

echo
info "Step 5: Patch waybar for compositor portability"

# 5a. Add niri/workspaces module to modules.json
MODULES_FILE="$WAYBAR_DIR/modules.json"
if [[ -f "$MODULES_FILE" ]]; then
    if grep -q '"niri/workspaces"' "$MODULES_FILE"; then
        ok "niri/workspaces module already in modules.json"
    else
        info "Adding niri/workspaces module to modules.json"
        if confirm "Patch $MODULES_FILE?"; then
            backup_file "$MODULES_FILE"
            cp "$SCRIPT_DIR/dotfiles/waybar/modules.json" "$MODULES_FILE"
            ok "modules.json updated with niri/workspaces"
        fi
    fi
else
    warn "modules.json not found at $MODULES_FILE"
fi

# 5b. Detect active waybar theme and patch its config
THEME_SETTING="$HOME/.config/ml4w/settings/waybar-theme.sh"
if [[ -f "$THEME_SETTING" ]]; then
    THEME_STYLE=$(cat "$THEME_SETTING")
    IFS=';' read -ra THEME_PARTS <<< "$THEME_STYLE"
    THEME_DIR="$WAYBAR_DIR/themes${THEME_PARTS[0]}"
    THEME_CONFIG="$THEME_DIR/config"

    if [[ -f "$THEME_CONFIG" ]]; then
        # Check if niri/workspaces is already in modules-center
        if grep -q '"niri/workspaces"' "$THEME_CONFIG"; then
            ok "niri/workspaces already in theme config modules-center"
        else
            info "Active theme: ${THEME_PARTS[0]}"
            info "Adding niri/workspaces to modules-center in theme config"
            if confirm "Patch $THEME_CONFIG?"; then
                backup_file "$THEME_CONFIG"
                # Insert niri/workspaces after hyprland/workspaces in modules-center
                sed -i '/"modules-center":/,/\]/ s/"hyprland\/workspaces"/"hyprland\/workspaces",\n        "niri\/workspaces"/' "$THEME_CONFIG"
                ok "Theme config patched"
            fi
        fi

        # Check for / create config-niri
        NIRI_THEME_CONFIG="$THEME_DIR/config-niri"
        if [[ -f "$NIRI_THEME_CONFIG" ]]; then
            ok "config-niri already exists for active theme"
        else
            info "Creating config-niri (waybar config with niri/workspaces in center)"
            if confirm "Create $NIRI_THEME_CONFIG?"; then
                sed 's/"hyprland\/workspaces"/"niri\/workspaces"/' "$THEME_CONFIG" > "$NIRI_THEME_CONFIG"
                ok "config-niri created"
            fi
        fi
    else
        warn "Theme config not found: $THEME_CONFIG"
    fi
else
    warn "ML4W waybar theme setting not found, skipping theme patching"
fi

# 5c. Patch launch.sh for compositor check
LAUNCH_FILE="$WAYBAR_DIR/launch.sh"
if [[ -f "$LAUNCH_FILE" ]]; then
    if grep -q 'XDG_CURRENT_DESKTOP.*niri' "$LAUNCH_FILE"; then
        ok "launch.sh already has compositor-aware logic"
    else
        info "Patching launch.sh to handle niri compositor"
        if confirm "Patch $LAUNCH_FILE?"; then
            backup_file "$LAUNCH_FILE"
            cp "$SCRIPT_DIR/dotfiles/waybar/launch.sh" "$LAUNCH_FILE"
            ok "launch.sh patched"
        fi
    fi
else
    warn "launch.sh not found at $LAUNCH_FILE"
fi

# ─────────────────────────────────────────────
# Step 6: Validate
# ─────────────────────────────────────────────

echo
info "Step 6: Validate niri config"

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
echo "  - Session script: $HOME/.local/bin/start-niri.sh"
echo "  - SDDM entry:    /usr/share/wayland-sessions/niri.desktop"
echo "  - Waybar:         Patched for dual-compositor support"
echo
info "Next steps:"
echo "  1. Edit $NIRI_CONFIG_DIR/config.kdl output section for your monitors"
echo "  2. Log out and select 'Niri' from the SDDM session picker"
echo "  3. Switch back to Hyprland anytime — waybar works on both"
echo
info "To uninstall, see README.md or run with --uninstall (if available)"
