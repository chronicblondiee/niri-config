#!/usr/bin/env bash
#
# Cleanup old Hyprland / ML4W dependencies
# Removes packages that are no longer needed after migrating to niri + noctalia-shell
#

set -euo pipefail

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

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Hyprland / ML4W Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# ─────────────────────────────────────────────
# Packages to remove
# ─────────────────────────────────────────────

# Hyprland compositor and ecosystem (fully replaced by niri + noctalia)
HYPRLAND_PKGS=(
    hyprland                    # compositor — replaced by niri
    hypridle                    # idle daemon — replaced by noctalia idle
    hyprlock                    # lock screen — replaced by noctalia lock
    hyprpaper                   # wallpaper — replaced by noctalia wallpaper
    hyprpicker                  # color picker — hyprland-specific
    hyprshade                   # screen shader — hyprland-specific
    hyprlauncher                # app launcher — replaced by noctalia launcher
    hyprcursor                  # cursor library — hyprland-specific
    hyprutils                   # shared library — hyprland-specific
    hyprgraphics                # graphics library — hyprland-specific
    hyprwayland-scanner         # wayland scanner — hyprland-specific
    hyprland-protocols          # wayland protocols — hyprland-specific
    aquamarine                  # rendering backend — hyprland-specific
    nwg-dock-hyprland           # dock — replaced by noctalia dock
    nwg-displays                # output config — hyprland-specific (use niri msg outputs)
    xdg-desktop-portal-hyprland # portal — replaced by xdg-desktop-portal-gnome
    xdg-desktop-portal-wlr      # portal — replaced by xdg-desktop-portal-gnome
    hyprpolkitagent             # polkit agent — replaced by polkit-kde-agent
)

# Old standalone tools replaced by noctalia-shell or niri builtins
OLD_TOOLS=(
    waybar        # bar — replaced by noctalia bar
    swaync        # notifications — replaced by noctalia notifications
    dunst         # notifications — replaced by noctalia notifications
    mako          # notifications — replaced by noctalia notifications
    swww          # wallpaper daemon — replaced by noctalia wallpaper
    swaybg        # wallpaper setter — replaced by noctalia wallpaper
    waypaper      # wallpaper picker — replaced by noctalia wallpaper picker
    swaylock      # lock screen — replaced by noctalia lock
    swayidle      # idle daemon — replaced by noctalia idle
    wofi          # launcher — replaced by noctalia launcher
    rofi          # launcher — replaced by noctalia launcher
    fuzzel        # launcher — replaced by noctalia launcher
    bemenu        # launcher — replaced by noctalia launcher
    wlogout       # power menu — replaced by noctalia session menu
    grim          # screenshots — niri has built-in screenshots
    slurp         # region select — niri has built-in screenshots
    grimblast-git # screenshot wrapper — niri has built-in screenshots
    nwg-look      # GTK theme editor — not needed for niri/noctalia
    wdisplays     # display config — use niri msg outputs
    kwalletmanager # KDE wallet GUI — not needed
)

# ML4W-specific packages (if migrating from ML4W dotfiles)
ML4W_PKGS=(
    ml4w-hyprland
    ml4w-dotfiles
    ml4w-welcome
    ml4w-config
)

# ─────────────────────────────────────────────
# Check what's actually installed
# ─────────────────────────────────────────────

check_installed() {
    local -n pkgs=$1
    local -n found=$2
    for pkg in "${pkgs[@]}"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            found+=("$pkg")
        fi
    done
}

INSTALLED_HYPRLAND=()
INSTALLED_OLD=()
INSTALLED_ML4W=()
check_installed HYPRLAND_PKGS INSTALLED_HYPRLAND
check_installed OLD_TOOLS INSTALLED_OLD
check_installed ML4W_PKGS INSTALLED_ML4W

# ─────────────────────────────────────────────
# Step 1: Remove Hyprland packages
# ─────────────────────────────────────────────

info "Step 1: Hyprland ecosystem packages"
echo

if [[ ${#INSTALLED_HYPRLAND[@]} -eq 0 ]]; then
    ok "No Hyprland packages found"
else
    echo "  The following Hyprland packages are installed:"
    for pkg in "${INSTALLED_HYPRLAND[@]}"; do
        desc=$(pacman -Qi "$pkg" 2>/dev/null | grep "^Description" | sed 's/Description     : //')
        echo -e "    ${YELLOW}${pkg}${NC} — ${desc}"
    done
    echo
    if confirm "Remove these ${#INSTALLED_HYPRLAND[@]} Hyprland packages?"; then
        failed=()
        for pkg in "${INSTALLED_HYPRLAND[@]}"; do
            if ! sudo pacman -Rns --noconfirm "$pkg" 2>/dev/null; then
                failed+=("$pkg")
            fi
        done
        if [[ ${#failed[@]} -gt 0 ]]; then
            warn "Could not remove (required by other packages): ${failed[*]}"
        else
            ok "Hyprland packages removed"
        fi
    else
        warn "Skipping Hyprland package removal"
    fi
fi

# ─────────────────────────────────────────────
# Step 2: Remove old standalone tools
# ─────────────────────────────────────────────

echo
info "Step 2: Old standalone tools (replaced by noctalia-shell)"
echo

if [[ ${#INSTALLED_OLD[@]} -eq 0 ]]; then
    ok "No old standalone tools found"
else
    echo "  The following packages are replaced by noctalia-shell:"
    for pkg in "${INSTALLED_OLD[@]}"; do
        desc=$(pacman -Qi "$pkg" 2>/dev/null | grep "^Description" | sed 's/Description     : //')
        echo -e "    ${YELLOW}${pkg}${NC} — ${desc}"
    done
    echo
    if confirm "Remove these ${#INSTALLED_OLD[@]} packages?"; then
        failed=()
        for pkg in "${INSTALLED_OLD[@]}"; do
            if ! sudo pacman -Rns --noconfirm "$pkg" 2>/dev/null; then
                failed+=("$pkg")
            fi
        done
        if [[ ${#failed[@]} -gt 0 ]]; then
            warn "Could not remove (required by other packages): ${failed[*]}"
        else
            ok "Old tools removed"
        fi
    else
        warn "Skipping old tool removal"
    fi
fi

# ─────────────────────────────────────────────
# Step 3: Remove ML4W packages
# ─────────────────────────────────────────────

echo
info "Step 3: ML4W dotfiles packages"
echo

if [[ ${#INSTALLED_ML4W[@]} -eq 0 ]]; then
    ok "No ML4W packages found"
else
    echo "  The following ML4W packages are installed:"
    for pkg in "${INSTALLED_ML4W[@]}"; do
        desc=$(pacman -Qi "$pkg" 2>/dev/null | grep "^Description" | sed 's/Description     : //')
        echo -e "    ${YELLOW}${pkg}${NC} — ${desc}"
    done
    echo
    if confirm "Remove these ${#INSTALLED_ML4W[@]} ML4W packages?"; then
        failed=()
        for pkg in "${INSTALLED_ML4W[@]}"; do
            if ! sudo pacman -Rns --noconfirm "$pkg" 2>/dev/null; then
                failed+=("$pkg")
            fi
        done
        if [[ ${#failed[@]} -gt 0 ]]; then
            warn "Could not remove (required by other packages): ${failed[*]}"
        else
            ok "ML4W packages removed"
        fi
    else
        warn "Skipping ML4W package removal"
    fi
fi

# ─────────────────────────────────────────────
# Step 4: Unmask/clean systemd user services
# ─────────────────────────────────────────────

echo
info "Step 4: Clean up systemd user services"

CONFLICTING_SERVICES=(
    swaync waybar dunst mako
    hypridle hyprpaper swayidle swaybg
    gnome-keyring-daemon gnome-keyring-ssh gcr-ssh-agent.socket
    kwallet kwalletd5 kwalletd6
)

for svc in "${CONFLICTING_SERVICES[@]}"; do
    if systemctl --user is-active "$svc" &>/dev/null 2>&1; then
        info "Stopping $svc"
        systemctl --user stop "$svc" 2>/dev/null || true
    fi
    if systemctl --user is-enabled "$svc" &>/dev/null 2>&1 || \
       systemctl --user cat "$svc" &>/dev/null 2>&1; then
        info "Cleaning up $svc"
        systemctl --user unmask "$svc" 2>/dev/null || true
        systemctl --user disable "$svc" 2>/dev/null || true
        ok "$svc cleaned up"
    fi
done

# ─────────────────────────────────────────────
# Step 5: Remove leftover config directories
# ─────────────────────────────────────────────

echo
info "Step 5: Remove leftover config directories"

CONFIG_DIRS=(
    "$HOME/.config/hypr"
    "$HOME/.config/waybar"
    "$HOME/.config/swaync"
    "$HOME/.config/swaylock"
    "$HOME/.config/swayidle"
    "$HOME/.config/wofi"
    "$HOME/.config/dunst"
    "$HOME/.config/mako"
    "$HOME/.config/fuzzel"
    "$HOME/.config/waypaper"
    "$HOME/.config/hyprlauncher"
    "$HOME/.config/nwg-dock-hyprland"
    "$HOME/.config/nwg-displays"
    "$HOME/.config/hyprshade"
    "$HOME/.config/wlogout"
    "$HOME/.config/rofi"
    "$HOME/.config/ml4w-hyprland"
    "$HOME/.config/ml4w-welcome"
)

FOUND_DIRS=()
for dir in "${CONFIG_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        FOUND_DIRS+=("$dir")
    fi
done

if [[ ${#FOUND_DIRS[@]} -eq 0 ]]; then
    ok "No leftover config directories found"
else
    echo "  The following config directories still exist:"
    for dir in "${FOUND_DIRS[@]}"; do
        count=$(find "$dir" -type f 2>/dev/null | wc -l)
        echo -e "    ${YELLOW}${dir}${NC} (${count} files)"
    done
    echo
    if confirm "Remove these ${#FOUND_DIRS[@]} directories?" "n"; then
        for dir in "${FOUND_DIRS[@]}"; do
            rm -rf "$dir"
            ok "Removed $dir"
        done
    else
        warn "Keeping config directories"
    fi
fi

# ─────────────────────────────────────────────
# Step 6: Remove orphaned dependencies
# ─────────────────────────────────────────────

echo
info "Step 6: Check for orphaned packages"

ORPHANS=$(pacman -Qdtq 2>/dev/null || true)
if [[ -z "$ORPHANS" ]]; then
    ok "No orphaned packages found"
else
    echo "  Orphaned packages (installed as deps, no longer needed):"
    echo "$ORPHANS" | while read -r pkg; do
        echo -e "    ${YELLOW}${pkg}${NC}"
    done
    echo
    if confirm "Remove orphaned packages?"; then
        sudo pacman -Rns $(pacman -Qdtq)
        ok "Orphaned packages removed"
    else
        warn "Keeping orphaned packages"
    fi
fi

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Cleanup Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
info "Kept packages (still used by niri + noctalia):"
echo "  - wl-clipboard    (clipboard, used by cliphist)"
echo "  - polkit-kde-agent (polkit authentication prompts)"
echo
info "If you want to remove any of these later:"
echo "  sudo pacman -Rns <package>"
echo
