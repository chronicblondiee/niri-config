# Niri Standalone Configuration

Standalone [niri](https://github.com/YaLTeR/niri) scrollable-tiling Wayland compositor configuration for Arch Linux.

## Prerequisites

- Arch Linux or derivative (CachyOS, EndeavourOS, etc.)
- SDDM display manager

## Quick Install

```bash
git clone git@github.com:chronicblondiee/niri-config.git ~/Projects/niri
cd ~/Projects/niri
./install.sh
```

The installer is interactive — it installs packages, copies configs/scripts, sets up waybar and wlogout. Every step asks for confirmation and creates backups before modifying files.

## Manual Install

### 1. Install packages

```bash
sudo pacman -S --needed niri swayidle swaylock xwayland-satellite xdg-desktop-portal-gnome
```

| Package | Purpose |
|---------|---------|
| `niri` | Scrollable-tiling Wayland compositor |
| `swayidle` | Idle manager |
| `swaylock` | Lock screen |
| `xwayland-satellite` | X11 app compatibility for niri |
| `xdg-desktop-portal-gnome` | Screen sharing, file dialogs |

### 2. Install configs

```bash
# Niri config
mkdir -p ~/.config/niri
cp config/niri/config.kdl ~/.config/niri/config.kdl

# Swaylock config
mkdir -p ~/.config/swaylock
cp config/swaylock/config ~/.config/swaylock/config

# Scripts
cp -r scripts/ ~/.config/niri/scripts/
chmod +x ~/.config/niri/scripts/*.sh

# Waybar
cp config/waybar/* ~/.config/waybar/
chmod +x ~/.config/waybar/launch.sh

# wlogout
mkdir -p ~/.config/wlogout
cp config/wlogout/layout ~/.config/wlogout/layout
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
| Bar | waybar |
| App launcher | rofi |
| Notifications | swaync |
| Wallpaper | swww + waypaper |
| Clipboard | cliphist |
| Terminal | kitty |
| Power menu | wlogout |
| Idle management | swayidle |
| Lock screen | swaylock |
| X11 compat | xwayland-satellite |

## Keybindings

### Core

| Binding | Action |
|---------|--------|
| `Super+Return` | Terminal (kitty) |
| `Super+B` | Browser (zen-browser) |
| `Super+E` | File manager (nautilus) |
| `Super+Ctrl+Return` | App launcher (rofi) |
| `Super+Q` | Close window |
| `Super+F` | Fullscreen |
| `Super+T` | Toggle floating |
| `Super+V` | Clipboard manager |
| `Super+Ctrl+Q` | Power menu (wlogout) |
| `Super+Alt+L` | Lock screen |
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
| `Super+Comma` | Consume window into column |
| `Super+Period` | Expel window from column |
| `Super+[` / `Super+]` | Consume/expel directional |
| `Super+Shift+V` | Switch focus floating/tiling |

### Utilities

| Binding | Action |
|---------|--------|
| `Print` | Screenshot (select region) |
| `Super+Print` | Screenshot full screen |
| `Super+Shift+Print` | Screenshot window |
| `Super+Shift+B` | Reload waybar |
| `Super+Ctrl+B` | Toggle waybar |
| `Super+Shift+W` | Random wallpaper |
| `Super+Ctrl+W` | Wallpaper picker |
| `Super+Ctrl+C` / `XF86Calculator` | Calculator |
| `Super+Escape` | Toggle keyboard shortcuts inhibit |
| `Super+Shift+P` | Power off monitors |
| Media keys | Volume, brightness, player controls |

## Monitors

The `output` section in `config.kdl` is hardware-specific:

```kdl
output "DP-2" {
    mode "2560x1440@143.995"
    position x=0 y=-560
    transform "270"
}

output "DP-1" {
    mode "3440x1440@239.991"
    position x=1440 y=0
}
```

Edit this for your setup. Run `niri msg outputs` (while niri is running) to list available outputs.

## Repo Structure

```
├── README.md
├── install.sh
├── config/
│   ├── niri/
│   │   └── config.kdl
│   ├── swaylock/
│   │   └── config
│   ├── waybar/
│   │   ├── config
│   │   ├── modules.json
│   │   ├── quicklinks.json
│   │   ├── style.css
│   │   └── launch.sh
│   └── wlogout/
│       └── layout
├── scripts/
│   ├── power.sh
│   ├── cliphist.sh
│   ├── toggle-waybar.sh
│   └── waypaper.sh
└── sessions/
    ├── niri.desktop
    └── start-niri.sh
```

## Uninstall

```bash
# Remove configs
rm -rf ~/.config/niri
rm -rf ~/.config/swaylock

# Remove session files
rm ~/.local/bin/start-niri.sh
sudo rm /usr/share/wayland-sessions/niri.desktop

# Restore waybar/wlogout backups (check for .bak files)
ls ~/.config/waybar/*.bak* ~/.config/wlogout/*.bak* 2>/dev/null

# Uninstall packages (optional)
sudo pacman -Rns niri swayidle swaylock xwayland-satellite xdg-desktop-portal-gnome
```
