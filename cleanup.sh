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
    hyprlauncher                # app launcher — replaced by noctalia/rofi
    nwg-dock-hyprland           # dock — replaced by noctalia dock
    nwg-displays                # output config — hyprland-specific (use niri msg outputs)
    xdg-desktop-portal-hyprland # portal — replaced by xdg-desktop-portal-gnome
)

# Old standalone tools replaced by noctalia-shell
OLD_TOOLS=(
    waybar      # bar — replaced by noctalia bar
    swaync      # notifications — replaced by noctalia notifications
    swww        # wallpaper daemon — replaced by noctalia wallpaper
    waypaper    # wallpaper picker — replaced by noctalia wallpaper picker
    swaylock    # lock screen — replaced by noctalia lock
    swayidle    # idle daemon — replaced by noctalia idle
    dunst       # notifications — replaced by noctalia notifications
    wofi        # launcher — replaced by noctalia launcher
    rofi        # launcher — replaced by noctalia launcher
    wlogout     # power menu — replaced by noctalia session menu
    grim        # screenshots — niri has built-in screenshots
    slurp       # region select — niri has built-in screenshots
    grimblast-git # screenshot wrapper — niri has built-in screenshots
    nwg-look    # GTK theme editor — not needed for niri/noctalia
    hyprpolkitagent # polkit agent — polkit-kde-agent available instead
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
check_installed HYPRLAND_PKGS INSTALLED_HYPRLAND
check_installed OLD_TOOLS INSTALLED_OLD

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
        sudo pacman -Rns "${INSTALLED_HYPRLAND[@]}"
        ok "Hyprland packages removed"
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
        sudo pacman -Rns "${INSTALLED_OLD[@]}"
        ok "Old tools removed"
    else
        warn "Skipping old tool removal"
    fi
fi

# ─────────────────────────────────────────────
# Step 3: Unmask/clean systemd user services
# ─────────────────────────────────────────────

echo
info "Step 3: Clean up systemd user services"

for svc in swaync waybar; do
    if systemctl --user is-enabled "$svc" &>/dev/null 2>&1 || \
       systemctl --user cat "$svc" &>/dev/null 2>&1; then
        info "Cleaning up $svc user service"
        systemctl --user unmask "$svc" 2>/dev/null || true
        systemctl --user disable "$svc" 2>/dev/null || true
        ok "$svc service cleaned up"
    fi
done

# ─────────────────────────────────────────────
# Step 4: Remove leftover config directories
# ─────────────────────────────────────────────

echo
info "Step 4: Remove leftover config directories"

CONFIG_DIRS=(
    "$HOME/.config/hypr"
    "$HOME/.config/waybar"
    "$HOME/.config/swaync"
    "$HOME/.config/swaylock"
    "$HOME/.config/wofi"
    "$HOME/.config/dunst"
    "$HOME/.config/waypaper"
    "$HOME/.config/nwg-dock-hyprland"
    "$HOME/.config/nwg-displays"
    "$HOME/.config/hyprshade"
    "$HOME/.config/wlogout"
    "$HOME/.config/rofi"
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
# Step 5: Remove orphaned dependencies
# ─────────────────────────────────────────────

echo
info "Step 5: Check for orphaned packages"

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
