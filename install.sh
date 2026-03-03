#!/usr/bin/env bash
#
# Niri Standalone Installer
# Sets up niri as a standalone compositor on Arch Linux
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYBAR_DIR="$HOME/.config/waybar"
NIRI_CONFIG_DIR="$HOME/.config/niri"
SWAYLOCK_CONFIG_DIR="$HOME/.config/swaylock"
WLOGOUT_DIR="$HOME/.config/wlogout"

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

# Detect connected monitors and generate niri output blocks
detect_monitors() {
    local output_blocks=""

    # Method 1: niri msg outputs (if niri is running)
    if command -v niri &>/dev/null && niri msg outputs &>/dev/null 2>&1; then
        info "Detecting monitors via niri..."
        local current_name="" current_mode=""
        local re_output='^Output .* \(([^)]+)\)$'
        local re_mode='^  Current mode: ([0-9]+x[0-9]+) @ ([0-9.]+) Hz'
        while IFS= read -r line; do
            if [[ "$line" =~ $re_output ]]; then
                if [[ -n "$current_name" && -n "$current_mode" ]]; then
                    output_blocks+="output \"$current_name\" {\n    mode \"$current_mode\"\n}\n\n"
                fi
                current_name="${BASH_REMATCH[1]}"
                current_mode=""
            elif [[ "$line" =~ $re_mode ]]; then
                current_mode="${BASH_REMATCH[1]}@${BASH_REMATCH[2]}"
            fi
        done < <(niri msg outputs 2>/dev/null)
        if [[ -n "$current_name" && -n "$current_mode" ]]; then
            output_blocks+="output \"$current_name\" {\n    mode \"$current_mode\"\n}\n\n"
        fi

    # Method 2: DRM sysfs fallback (works from TTY, no compositor needed)
    else
        info "Detecting monitors via DRM sysfs..."
        for connector_dir in /sys/class/drm/card*-*/; do
            local connector_status
            connector_status=$(cat "$connector_dir/status" 2>/dev/null) || continue
            if [[ "$connector_status" == "connected" ]]; then
                local connector_name
                connector_name=$(basename "$connector_dir" | sed 's/^card[0-9]*-//')
                local preferred_mode
                preferred_mode=$(head -1 "$connector_dir/modes" 2>/dev/null) || continue
                if [[ -n "$preferred_mode" ]]; then
                    output_blocks+="output \"$connector_name\" {\n    mode \"$preferred_mode\"\n}\n\n"
                fi
            fi
        done
    fi

    echo -e "$output_blocks"
}

# Inject output blocks into the installed niri config
inject_outputs() {
    local config_file="$1"
    local output_blocks="$2"

    if [[ -z "$output_blocks" ]]; then
        warn "No monitors detected, leaving output section empty (niri will auto-detect)"
        sed -i '/^\/\/ OUTPUT_BLOCK_START$/,/^\/\/ OUTPUT_BLOCK_END$/c\// (no outputs configured — niri will auto-detect)' "$config_file"
        return
    fi

    local replacement
    replacement="// OUTPUT_BLOCK_START\n${output_blocks}// OUTPUT_BLOCK_END"
    sed -i "/^\/\/ OUTPUT_BLOCK_START$/,/^\/\/ OUTPUT_BLOCK_END$/c\\${replacement}" "$config_file"
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
# Step 2: Install packages
# ─────────────────────────────────────────────

echo
info "Step 2: Install packages"

PACKAGES=(niri swayidle swaylock xwayland-satellite xdg-desktop-portal-gnome)
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
# Step 3a: Detect monitors and configure outputs
# ─────────────────────────────────────────────

echo
info "Step 3a: Detect and configure monitor outputs"

if grep -q 'OUTPUT_BLOCK_START' "$NIRI_CONFIG_DIR/config.kdl"; then
    DETECTED_OUTPUTS=$(detect_monitors)

    if [[ -n "$DETECTED_OUTPUTS" ]]; then
        echo
        info "Detected monitors:"
        echo -e "$DETECTED_OUTPUTS" | sed 's/^/  /'
        echo
        if confirm "Apply these monitor settings to niri config?"; then
            inject_outputs "$NIRI_CONFIG_DIR/config.kdl" "$DETECTED_OUTPUTS"
            ok "Monitor outputs configured"
        else
            inject_outputs "$NIRI_CONFIG_DIR/config.kdl" ""
            warn "Skipped — niri will auto-detect monitors at runtime"
        fi
    else
        inject_outputs "$NIRI_CONFIG_DIR/config.kdl" ""
        warn "No monitors detected — niri will auto-detect at runtime"
    fi
else
    ok "Output section already configured (no placeholder markers found)"
fi

# ─────────────────────────────────────────────
# Step 3b: Copy swaylock config
# ─────────────────────────────────────────────

echo
info "Step 3b: Install swaylock config"

mkdir -p "$SWAYLOCK_CONFIG_DIR"

if [[ -f "$SWAYLOCK_CONFIG_DIR/config" ]]; then
    ok "Swaylock config already exists at $SWAYLOCK_CONFIG_DIR/config"
    if confirm "Overwrite with repo version?" "n"; then
        backup_file "$SWAYLOCK_CONFIG_DIR/config"
        cp "$SCRIPT_DIR/config/swaylock/config" "$SWAYLOCK_CONFIG_DIR/config"
        ok "Swaylock config updated"
    else
        warn "Keeping existing swaylock config"
    fi
else
    cp "$SCRIPT_DIR/config/swaylock/config" "$SWAYLOCK_CONFIG_DIR/config"
    ok "Swaylock config installed to $SWAYLOCK_CONFIG_DIR/config"
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
# Step 5: Install scripts
# ─────────────────────────────────────────────

echo
info "Step 5: Install niri scripts"

SCRIPTS_DIR="$NIRI_CONFIG_DIR/scripts"
mkdir -p "$SCRIPTS_DIR"

for script in "$SCRIPT_DIR"/scripts/*.sh; do
    script_name=$(basename "$script")
    dest="$SCRIPTS_DIR/$script_name"
    if [[ -f "$dest" ]]; then
        backup_file "$dest"
    fi
    cp "$script" "$dest"
    chmod +x "$dest"
done
ok "Scripts installed to $SCRIPTS_DIR"

# ─────────────────────────────────────────────
# Step 6: Install waybar config
# ─────────────────────────────────────────────

echo
info "Step 6: Install standalone waybar config"

mkdir -p "$WAYBAR_DIR"

for waybar_file in config modules.json quicklinks.json style.css launch.sh; do
    src="$SCRIPT_DIR/config/waybar/$waybar_file"
    dest="$WAYBAR_DIR/$waybar_file"
    if [[ -f "$src" ]]; then
        if [[ -f "$dest" ]]; then
            backup_file "$dest"
        fi
        cp "$src" "$dest"
        [[ "$waybar_file" == "launch.sh" ]] && chmod +x "$dest"
    fi
done
ok "Waybar config installed to $WAYBAR_DIR"

# ─────────────────────────────────────────────
# Step 7: Install wlogout layout
# ─────────────────────────────────────────────

echo
info "Step 7: Install wlogout layout"

mkdir -p "$WLOGOUT_DIR"

if [[ -f "$WLOGOUT_DIR/layout" ]]; then
    backup_file "$WLOGOUT_DIR/layout"
fi
cp "$SCRIPT_DIR/config/wlogout/layout" "$WLOGOUT_DIR/layout"
ok "wlogout layout installed to $WLOGOUT_DIR/layout"

# ─────────────────────────────────────────────
# Step 8: Validate
# ─────────────────────────────────────────────

echo
info "Step 8: Validate niri config"

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
echo "  - Niri scripts:   $NIRI_CONFIG_DIR/scripts/"
echo "  - Swaylock:       $SWAYLOCK_CONFIG_DIR/config"
echo "  - Session script: $HOME/.local/bin/start-niri.sh"
echo "  - SDDM entry:    /usr/share/wayland-sessions/niri.desktop"
echo "  - Waybar:         $WAYBAR_DIR/"
echo "  - wlogout:        $WLOGOUT_DIR/layout"
echo
info "Next steps:"
echo "  1. Log out and select 'Niri' from the SDDM session picker"
echo "  2. To customize monitor settings later, edit the output section in:"
echo "     $NIRI_CONFIG_DIR/config.kdl"
echo
