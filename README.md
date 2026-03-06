# Niri Standalone Configuration

Standalone [niri](https://github.com/YaLTeR/niri) scrollable-tiling Wayland compositor configuration for Arch Linux.

## Prerequisites

- Arch Linux or derivative (CachyOS, EndeavourOS, etc.)
- SDDM display manager
- An AUR helper (`paru` or `yay`) for noctalia-shell

## Quick Install

```bash
git clone git@github.com:chronicblondiee/niri-config.git
cd niri-config
./install.sh
```

The installer is interactive and idempotent — every step asks for confirmation and creates `.bak` backups before modifying files. It handles:

1. **Conflict detection** — finds existing compositors (Hyprland, Sway) and offers to run `cleanup.sh`
2. **Broken symlink cleanup** — scans `~/.config` for dead links from old setups
3. **Package installation** — official repos via `pacman`, AUR via `paru`/`yay`
4. **Config deployment** — niri, noctalia-shell, kitty, fish, GTK dark theme
5. **Directory setup** — `~/Pictures/Wallpapers/` and `~/Pictures/Screenshots/`
6. **SSH agent** — enables `ssh-agent.socket`, disables conflicting agents (gnome-keyring, kwallet, gcr)
7. **Service cleanup** — masks conflicting notification daemons (swaync, dunst, mako)
8. **XDG portals** — configures `xdg-desktop-portal-gnome`, removes conflicting backends
9. **Default shell** — sets fish via `chsh`
10. **Session files** — installs `start-niri.sh`, SDDM session entry, Catppuccin Mocha SDDM theme
11. **Validation** — runs `niri validate`

After installing, log out and select **Niri** from the SDDM session picker.

## Cleanup

If migrating from Hyprland, Sway, or ML4W, run the cleanup script to remove conflicting packages, services, and configs:

```bash
./cleanup.sh
```

This handles:
- Hyprland ecosystem packages (hyprland, hypridle, hyprlock, hyprpaper, etc.)
- Old standalone tools replaced by noctalia-shell (waybar, swaync, dunst, swww, rofi, etc.)
- ML4W dotfiles packages
- Conflicting systemd services (notification daemons, SSH agents, wallpaper daemons)
- Leftover config directories
- Orphaned package dependencies

## Manual Install

### 1. Install packages

```bash
# Official repos
sudo pacman -S --needed niri xwayland-satellite xdg-desktop-portal-gnome \
    qt6-svg qt6-declarative kitty fish nautilus wl-clipboard cliphist \
    polkit-kde-agent lxqt-openssh-askpass openssh

# AUR (noctalia-shell provides bar, notifications, wallpaper, lock screen)
paru -S noctalia-shell catppuccin-sddm-theme-mocha zen-browser-bin
```

| Package | Purpose |
|---------|---------|
| `niri` | Scrollable-tiling Wayland compositor |
| `noctalia-shell` | Desktop shell (bar, notifications, wallpaper, lock screen) |
| `xwayland-satellite` | X11 app compatibility for niri |
| `xdg-desktop-portal-gnome` | Screen sharing, file dialogs |
| `kitty` | Terminal emulator |
| `fish` | Fish shell |
| `nautilus` | File manager |
| `wl-clipboard` + `cliphist` | Clipboard history |
| `polkit-kde-agent` | Polkit authentication prompts |
| `lxqt-openssh-askpass` | SSH key passphrase GUI prompt |
| `catppuccin-sddm-theme-mocha` | SDDM login theme (AUR) |
| `zen-browser-bin` | Web browser (AUR) |

### 2. Install configs

```bash
# Niri config
mkdir -p ~/.config/niri
cp config/niri/config.kdl ~/.config/niri/config.kdl

# Noctalia shell config (replace __HOME__ with your home directory)
mkdir -p ~/.config/noctalia
sed "s|__HOME__|$HOME|g" config/noctalia/settings.json > ~/.config/noctalia/settings.json

# Kitty terminal (Catppuccin Mocha theme)
mkdir -p ~/.config/kitty
cp config/kitty/kitty.conf ~/.config/kitty/kitty.conf

# Fish shell
mkdir -p ~/.config/fish
cp config/fish/config.fish ~/.config/fish/config.fish

# GTK dark theme
mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0
cp config/gtk-3.0/settings.ini ~/.config/gtk-3.0/settings.ini
cp config/gtk-4.0/settings.ini ~/.config/gtk-4.0/settings.ini

# Wallpaper + screenshot directories
mkdir -p ~/Pictures/Wallpapers ~/Pictures/Screenshots
```

Edit the `output` section at the top of `config.kdl` for your monitors.

### 3. Set up services

```bash
# SSH agent (systemd socket + GUI passphrase prompt)
systemctl --user enable --now ssh-agent.socket
systemctl --user disable gcr-ssh-agent.socket 2>/dev/null || true

# Disable conflicting notification daemons
systemctl --user mask swaync 2>/dev/null || true
systemctl --user mask dunst 2>/dev/null || true

# Disable conflicting SSH agents (if present)
systemctl --user disable gnome-keyring-ssh.service 2>/dev/null || true
systemctl --user disable kwalletd5.service 2>/dev/null || true
systemctl --user disable kwalletd6.service 2>/dev/null || true

# Remove conflicting portal backends
sudo pacman -Rns xdg-desktop-portal-hyprland xdg-desktop-portal-wlr 2>/dev/null || true

# XDG portal config for niri
mkdir -p ~/.config/xdg-desktop-portal
cat > ~/.config/xdg-desktop-portal/niri-portals.conf <<'EOF'
[preferred]
default=gnome
org.freedesktop.impl.portal.Access=gnome
org.freedesktop.impl.portal.FileChooser=gnome
org.freedesktop.impl.portal.Screenshot=gnome
org.freedesktop.impl.portal.Screencast=gnome
EOF

# Set fish as default shell
chsh -s /usr/bin/fish
```

### 4. Install session files

```bash
mkdir -p ~/.local/bin
cp sessions/start-niri.sh ~/.local/bin/start-niri.sh
chmod +x ~/.local/bin/start-niri.sh

# SDDM session entry (requires sudo)
sed "s|/home/brown|$HOME|g" sessions/niri.desktop | sudo tee /usr/share/wayland-sessions/niri.desktop >/dev/null

# SDDM Catppuccin theme (requires sudo)
# Appends [Theme] section if missing, or updates existing Current= line
if grep -q '^\[Theme\]' /etc/sddm.conf 2>/dev/null; then
    sudo sed -i '/^\[Theme\]/,/^\[/{s/^Current=.*/Current=catppuccin-mocha-mauve/}' /etc/sddm.conf
else
    printf '\n[Theme]\nCurrent=catppuccin-mocha-mauve\n' | sudo tee -a /etc/sddm.conf >/dev/null
fi
```

### 5. Validate

```bash
niri validate
```

## Components

| Component | Tool |
|-----------|------|
| Compositor | niri |
| Bar | noctalia-shell |
| App launcher | noctalia-shell |
| Notifications | noctalia-shell |
| Wallpaper | noctalia-shell |
| Clipboard | noctalia-shell (cliphist backend) |
| Terminal | kitty |
| Power/session menu | noctalia-shell |
| Lock screen | noctalia-shell |
| X11 compat | xwayland-satellite |
| SSH agent | systemd ssh-agent.socket + lxqt-openssh-askpass |
| Login theme | catppuccin-sddm-theme-mocha |

## Keybindings

### Core

| Binding | Action |
|---------|--------|
| `Super+Return` | Terminal (kitty) |
| `Super+B` | Browser (zen-browser) |
| `Super+E` | File manager (nautilus) |
| `Super+Space` / `Super+Ctrl+Return` | App launcher |
| `Super+Shift+Space` | Emoji picker |
| `Super+Q` | Close window |
| `Super+F` | Fullscreen |
| `Super+T` | Toggle floating |
| `Super+V` | Clipboard manager |
| `Super+Alt+L` | Lock screen |
| `Super+Ctrl+Q` | Session / power menu |
| `Super+Shift+E` | Quit niri |
| `Super+Slash` | Show hotkey overlay |
| `Super+O` | Toggle overview |

### Navigation

| Binding | Action |
|---------|--------|
| `Super+Arrows` / `Super+HJKL` | Focus column/window |
| `Super+Shift+Arrows` / `Super+Shift+HJKL` | Focus monitor |
| `Super+1-9, 0` | Focus workspace 1-10 |
| `Super+Tab` / `Super+Shift+Tab` | Next/prev workspace |
| `Super+Home` / `Super+End` | Focus first/last column |
| `Alt+Tab` | Cycle windows |

### Window Management

| Binding | Action |
|---------|--------|
| `Super+Ctrl+Arrows` / `Super+Ctrl+HJKL` | Move column/window |
| `Super+Shift+1-9, 0` | Move window to workspace |
| `Super+Shift+Ctrl+Arrows/HJKL` | Move column to monitor |
| `Super+Alt+Arrows` | Resize (10% steps) |
| `Super+Minus` / `Super+Equal` | Resize column width |
| `Super+Shift+Minus` / `Super+Shift+Equal` | Resize window height |
| `Super+R` | Cycle preset column widths |
| `Super+Shift+R` | Cycle preset window heights |
| `Super+Ctrl+R` | Reset window height |
| `Super+C` | Center column |
| `Super+M` | Maximize column |
| `Super+Shift+F` | Expand column to available width |
| `Super+W` | Toggle tabbed column display |
| `Super+Period` | Expel window from column |
| `Super+[` / `Super+]` | Consume/expel directional |
| `Super+Shift+V` | Switch focus floating/tiling |

### Noctalia Shell

| Binding | Action |
|---------|--------|
| `Super+Comma` | Settings panel |
| `Super+A` | Control center |
| `Super+Ctrl+A` | Calendar |
| `Super+Ctrl+I` | Network panel |
| `Super+N` | Notification history |
| `Super+Shift+N` | Toggle Do Not Disturb |
| `Super+Shift+B` | Toggle bar |
| `Super+D` | Toggle dock |
| `Super+Shift+W` | Random wallpaper |
| `Super+Ctrl+W` | Wallpaper picker |
| `Super+Ctrl+D` | Toggle dark mode |
| `Super+Ctrl+N` | Toggle night light |
| `Super+Shift+M` | Media panel |
| Media keys | Volume, brightness, player controls (with OSD) |

### Utilities

| Binding | Action |
|---------|--------|
| `Super+S` / `Print` | Screenshot (select region) |
| `Super+Shift+S` / `Super+Print` | Screenshot full screen |
| `Super+Alt+S` / `Super+Shift+Print` | Screenshot window |
| `Super+Ctrl+C` / `XF86Calculator` | Calculator |
| `Super+Escape` | Toggle keyboard shortcuts inhibit |
| `Super+Shift+P` | Power off monitors |

## Monitors

Monitor configuration lives in the `output` blocks at the top of `config.kdl`. Niri hot-reloads the config on save, so changes apply immediately.

### Finding your outputs

While niri is running:

```bash
niri msg outputs
```

This prints each output's connector name (e.g. `eDP-1`, `DP-1`, `HDMI-A-1`), current mode, available modes, scale, and transform.

From a TTY (no compositor running), check DRM sysfs:

```bash
# List connected outputs
for d in /sys/class/drm/card*-*/; do
    [ "$(cat "$d/status" 2>/dev/null)" = "connected" ] && echo "$(basename "$d" | sed 's/^card[0-9]*-//') — $(head -1 "$d/modes")"
done
```

### Configuration options

Edit `~/.config/niri/config.kdl` (or `config/niri/config.kdl` in the repo):

```kdl
output "eDP-1" {
    mode "1920x1080@60.001"
    scale 1.0
}
```

Each `output` block supports:

| Property | Description | Example |
|----------|-------------|---------|
| `mode` | Resolution and refresh rate | `"2560x1440@143.995"` |
| `scale` | UI scaling factor (1.0 = no scaling) | `1.0`, `1.25`, `1.5`, `2.0` |
| `position` | Pixel position in the layout | `x=1920 y=0` |
| `transform` | Rotation | `"normal"`, `"90"`, `"180"`, `"270"` |

### Multi-monitor example

```kdl
// Vertical monitor on the left
output "DP-2" {
    mode "2560x1440@143.995"
    position x=0 y=-560
    transform "270"
}

// Ultrawide as primary
output "DP-1" {
    mode "3440x1440@239.991"
    position x=1440 y=0
}
```

Position values are in physical pixels. Use `niri msg outputs` to check logical vs physical sizes when calculating positions.

### Tips

- Omit the `output` block entirely to let niri auto-detect (uses preferred mode, scale 1.0)
- Set `scale 1.0` explicitly to prevent niri from auto-scaling on HiDPI panels
- Available modes are listed in `niri msg outputs` — use the exact `WxH@rate` string
- Changes take effect immediately on save (no restart needed)

## Repo Structure

```
├── README.md
├── CLAUDE.md
├── install.sh
├── cleanup.sh
├── config/
│   ├── niri/
│   │   └── config.kdl
│   ├── noctalia/
│   │   └── settings.json
│   ├── kitty/
│   │   └── kitty.conf
│   ├── fish/
│   │   └── config.fish
│   ├── gtk-3.0/
│   │   └── settings.ini
│   └── gtk-4.0/
│       └── settings.ini
└── sessions/
    ├── niri.desktop
    └── start-niri.sh
```

## Uninstall

```bash
# Remove configs
rm -rf ~/.config/niri ~/.config/noctalia ~/.config/xdg-desktop-portal/niri-portals.conf

# Remove session files
rm ~/.local/bin/start-niri.sh
sudo rm /usr/share/wayland-sessions/niri.desktop

# Restore default shell
chsh -s /bin/bash

# Disable SSH agent
systemctl --user disable ssh-agent.socket

# Uninstall packages (optional)
sudo pacman -Rns niri xwayland-satellite xdg-desktop-portal-gnome lxqt-openssh-askpass
paru -Rns noctalia-shell catppuccin-sddm-theme-mocha zen-browser-bin
```
