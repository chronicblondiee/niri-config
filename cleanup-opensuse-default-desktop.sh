#!/usr/bin/env bash
#
# Remove openSUSE's default minimal-X fallback desktop (IceWM + friends) once
# niri is confirmed working. Run this AFTER install-opensuse.sh and AFTER you
# have successfully logged into Niri at least once — not before.
#
# Deliberately does NOT touch xorg-x11-server/xinit: SDDM's login greeter
# still runs under X11 by default on this system, so removing Xorg would
# break the login screen itself, not just the fallback desktop.
#

set -euo pipefail

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

pkg_installed() { rpm -q "$1" &>/dev/null; }

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  openSUSE Default Desktop Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

if ! command -v zypper &>/dev/null; then
    err "zypper not found. This script requires openSUSE Tumbleweed or Slowroll."
    exit 1
fi

# ─────────────────────────────────────────────
# Safety gate: confirm niri is actually the working default before we
# remove the fallback desktop it's replacing
# ─────────────────────────────────────────────

SDDM_STATE_CONF="/var/lib/sddm/state.conf"
NIRI_IS_DEFAULT=false
if sudo test -f "$SDDM_STATE_CONF" && sudo grep -q "^Session=niri.desktop$" "$SDDM_STATE_CONF" 2>/dev/null; then
    NIRI_IS_DEFAULT=true
fi

if [[ "$NIRI_IS_DEFAULT" == "true" ]]; then
    ok "SDDM's default session is niri — looks safe to remove the fallback desktop"
else
    warn "SDDM does not currently show niri.desktop as the last/default session"
    warn "(run install-opensuse.sh's SDDM step first, and confirm you can log"
    warn "into Niri successfully after a reboot before running this script)"
    if ! confirm "Continue anyway?" "n"; then
        info "Aborted — nothing removed"
        exit 0
    fi
fi

# ─────────────────────────────────────────────
# Step 1: Remove IceWM (openSUSE minimal-X's default fallback desktop)
# ─────────────────────────────────────────────

echo
info "Step 1: IceWM fallback desktop packages"
echo

ICEWM_PKGS=(icewm icewm-default icewm-lang icewm-theme-branding)
INSTALLED_ICEWM=()
for pkg in "${ICEWM_PKGS[@]}"; do
    pkg_installed "$pkg" && INSTALLED_ICEWM+=("$pkg")
done

if [[ ${#INSTALLED_ICEWM[@]} -eq 0 ]]; then
    ok "No IceWM packages found"
else
    echo "  The following packages are installed:"
    for pkg in "${INSTALLED_ICEWM[@]}"; do
        desc=$(rpm -q --qf '%{SUMMARY}' "$pkg" 2>/dev/null)
        echo -e "    ${YELLOW}${pkg}${NC} — ${desc}"
    done
    echo
    if confirm "Remove these ${#INSTALLED_ICEWM[@]} IceWM packages?"; then
        if sudo zypper remove -y --clean-deps "${INSTALLED_ICEWM[@]}"; then
            ok "IceWM packages removed"
        else
            warn "Some packages could not be removed — check zypper output above"
        fi
    else
        warn "Skipping IceWM package removal"
    fi
fi

# ─────────────────────────────────────────────
# Step 2: Clean up dangling xsession alternatives left behind by IceWM
# ─────────────────────────────────────────────

echo
info "Step 2: Dangling xsession entries"
echo

DEFAULT_XSESSION_LINK="/usr/share/xsessions/default.desktop"
DEFAULT_XSESSION_ALT="/etc/alternatives/default-xsession.desktop"

if [[ -L "$DEFAULT_XSESSION_LINK" ]] && [[ ! -e "$DEFAULT_XSESSION_LINK" ]]; then
    if confirm "Remove dangling symlink $DEFAULT_XSESSION_LINK?"; then
        sudo rm -f "$DEFAULT_XSESSION_LINK"
        ok "Removed $DEFAULT_XSESSION_LINK"
    fi
elif [[ -e "$DEFAULT_XSESSION_LINK" ]]; then
    ok "$DEFAULT_XSESSION_LINK still points to a valid session — leaving it"
else
    ok "No dangling xsession symlink found"
fi

if [[ -L "$DEFAULT_XSESSION_ALT" ]] && [[ ! -e "$DEFAULT_XSESSION_ALT" ]]; then
    if confirm "Remove dangling alternatives symlink $DEFAULT_XSESSION_ALT?"; then
        sudo rm -f "$DEFAULT_XSESSION_ALT"
        ok "Removed $DEFAULT_XSESSION_ALT"
    fi
fi

# ─────────────────────────────────────────────
# Step 3: Orphaned packages left behind after removal
# ─────────────────────────────────────────────

echo
info "Step 3: Orphaned packages"
echo

ORPHANS=$(zypper --quiet packages --orphaned 2>/dev/null | awk -F'|' 'NR>2 {gsub(/^ +| +$/,"",$3); if ($3 != "") print $3}')
if [[ -z "$ORPHANS" ]]; then
    ok "No orphaned packages found"
else
    echo "  Orphaned packages (pulled in as dependencies, no longer needed):"
    echo "$ORPHANS" | while read -r pkg; do
        echo -e "    ${YELLOW}${pkg}${NC}"
    done
    echo
    if confirm "Remove orphaned packages?" "n"; then
        # shellcheck disable=SC2086
        sudo zypper remove -y $ORPHANS
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
info "Deliberately kept (still required):"
echo "  - xorg-x11-server, xinit — SDDM's login greeter runs under X11 by"
echo "    default on this system; removing these would break the login"
echo "    screen, not just the old desktop. Niri itself runs under Wayland"
echo "    via xwayland-satellite regardless."
echo "  - patterns-base-x11 / patterns-yast-x11_yast — base X11 metapackages,"
echo "    low value/higher risk to force off"
echo
info "If you later want a fully Wayland-native greeter (no Xorg at all),"
info "that requires switching SDDM's General.DisplayServer to 'wayland' and"
info "confirming a working SDDM Wayland greeter theme — a separate, riskier"
info "change not done here."
echo
