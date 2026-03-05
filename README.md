# Niri Standalone Configuration

Standalone [niri](https://github.com/YaLTeR/niri) scrollable-tiling Wayland compositor configuration for Arch Linux.

## Prerequisites

- Arch Linux or derivative (CachyOS, EndeavourOS, etc.)
- SDDM display manager
- An AUR helper (`paru` or `yay`) for noctalia-shell

## Quick Install

```bash
git clone git@github.com:chronicblondiee/niri-config.git ~/Projects/niri
cd ~/Projects/niri
./install.sh
```

The installer is interactive — it installs packages, copies configs and scripts. Every step asks for confirmation and creates backups before modifying files.

## Manual Install

### 1. Install packages

```bash
# Official repos
sudo pacman -S --needed niri xwayland-satellite xdg-desktop-portal-gnome

# AUR (noctalia-shell provides bar, notifications, wallpaper, lock screen)
paru -S noctalia-shell
```

| Package | Purpose |
|---------|---------|
| `niri` | Scrollable-tiling Wayland compositor |
| `noctalia-shell` | Desktop shell (bar, notifications, wallpaper, lock screen) |
| `xwayland-satellite` | X11 app compatibility for niri |
| `xdg-desktop-portal-gnome` | Screen sharing, file dialogs |

### 2. Install configs

```bash
# Niri config
mkdir -p ~/.config/niri
cp config/niri/config.kdl ~/.config/niri/config.kdl

# Noctalia shell config (replace __HOME__ with your home directory)
mkdir -p ~/.config/noctalia
sed "s|__HOME__|$HOME|g" config/noctalia/settings.json > ~/.config/noctalia/settings.json

# Wallpaper directory
mkdir -p ~/Pictures/Wallpapers

# Disable swaync if installed (conflicts with noctalia notifications)
systemctl --user mask swaync 2>/dev/null || true
```

Edit the `output` section at the top of `config.kdl` for your monitors.

### 3. Install session files

```bash
cp sessions/start-niri.sh ~/.local/bin/start-niri.sh
chmod +x ~/.local/bin/start-niri.sh

# SDDM session entry (requires sudo)
sudo cp sessions/niri.desktop /usr/share/wayland-sessions/niri.desktop
```

Update the `Exec=` path in `niri.desktop` if your home directory differs.

### 4. Validate

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
| `Print` | Screenshot (select region) |
| `Super+Print` | Screenshot full screen |
| `Super+Shift+Print` | Screenshot window |
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
├── install.sh
├── config/
│   ├── niri/
│   │   └── config.kdl
│   └── noctalia/
│       └── settings.json
└── sessions/
    ├── niri.desktop
    └── start-niri.sh
```

## Uninstall

```bash
# Remove configs
rm -rf ~/.config/niri

# Remove session files
rm ~/.local/bin/start-niri.sh
sudo rm /usr/share/wayland-sessions/niri.desktop

# Uninstall packages (optional)
sudo pacman -Rns niri xwayland-satellite xdg-desktop-portal-gnome
paru -Rns noctalia-shell
```
