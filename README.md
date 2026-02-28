# Niri + Hyprland Dual-Compositor Setup

Run [niri](https://github.com/YaLTeR/niri) alongside [Hyprland](https://hyprland.org/) with [ML4W dotfiles](https://github.com/mylinuxforwork/dotfiles), sharing waybar, rofi, swaync, swww, cliphist, and kitty between both compositors.

## Prerequisites

- Arch Linux or derivative (CachyOS, EndeavourOS, etc.)
- SDDM display manager
- Hyprland + ML4W dotfiles installed and working

## Quick Install

```bash
git clone <repo-url> ~/Projects/niri
cd ~/Projects/niri
./install.sh
```

The installer is interactive — it checks prerequisites, installs packages, copies configs, and patches waybar. Every step asks for confirmation and creates backups before modifying files.

## Manual Install

### 1. Install packages

```bash
sudo pacman -S --needed niri swayidle swaylock xwayland-satellite
```

| Package | Purpose |
|---------|---------|
| `niri` | Scrollable-tiling Wayland compositor |
| `swayidle` | Idle manager (replaces hypridle) |
| `swaylock` | Lock screen (replaces hyprlock) |
| `xwayland-satellite` | X11 app compatibility for niri |

### 2. Install niri config

```bash
mkdir -p ~/.config/niri
cp config/niri/config.kdl ~/.config/niri/config.kdl
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

### 4. Patch waybar

Three changes make waybar work on both compositors:

**a) Add niri/workspaces module to `~/.config/waybar/modules.json`:**

Add the snippet from `config/waybar/modules-niri.json` alongside the existing `hyprland/workspaces` block. Waybar only renders modules for the active compositor.

**b) Add niri/workspaces to your active waybar theme config:**

In your theme's `config` file (e.g., `~/.config/waybar/themes/ml4w-glass-center/config`), add `"niri/workspaces"` to `modules-center`:

```json
"modules-center": ["hyprland/workspaces", "niri/workspaces", "custom/empty"]
```

Or create a separate `config-niri` that replaces `hyprland/workspaces` with `niri/workspaces` — the patched `launch.sh` will use it automatically.

**c) Patch `~/.config/waybar/launch.sh`:**

Wrap the Hyprland-specific `hyprctl` line in a compositor check so waybar launches cleanly on niri. See `dotfiles/waybar/launch.sh` for the patched version.

### 5. Validate

```bash
niri validate
```

## Shared vs Niri-Specific

| Component | Shared | Niri-Specific |
|-----------|--------|---------------|
| waybar | Shared (patched for portability) | `config-niri` theme variant |
| rofi | Shared | — |
| swaync | Shared | — |
| swww | Shared | — |
| cliphist | Shared | — |
| kitty | Shared | — |
| wlogout | Shared | — |
| Idle management | — | swayidle (replaces hypridle) |
| Lock screen | — | swaylock (replaces hyprlock) |
| X11 compat | — | xwayland-satellite |
| Config | — | `~/.config/niri/config.kdl` |
| Session | — | `start-niri.sh` + `niri.desktop` |

## Keybindings

All keybindings match Hyprland muscle memory where possible.

### Core

| Binding | Action |
|---------|--------|
| `Super+Return` | Terminal (kitty) |
| `Super+B` | Browser |
| `Super+E` | File manager |
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

### Workspaces

| Binding | Action |
|---------|--------|
| `Super+Ctrl+Page_Down/Up` | Move column to workspace down/up |
| `Super+Shift+Page_Down/Up` | Reorder workspace down/up |
| `Super+Scroll` | Scroll through workspaces |

### Utilities

| Binding | Action |
|---------|--------|
| `Print` | Screenshot (select region) |
| `Super+Print` | Screenshot full screen |
| `Super+Shift+Print` | Screenshot window |
| `Super+Alt+F` | Screenshot screen (instant) |
| `Super+Alt+S` | Screenshot (instant) |
| `Super+Shift+B` | Reload waybar |
| `Super+Ctrl+B` | Toggle waybar |
| `Super+Shift+W` | Random wallpaper |
| `Super+Ctrl+W` | Wallpaper picker |
| `Super+Ctrl+E` | Emoji picker |
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
├── README.md                  # This file
├── install.sh                 # Interactive installer
├── config/
│   ├── niri/
│   │   └── config.kdl         # Niri compositor config
│   └── waybar/
│       └── modules-niri.json  # niri/workspaces module snippet
├── sessions/
│   ├── niri.desktop           # SDDM session entry
│   └── start-niri.sh          # Session startup wrapper
└── dotfiles/
    └── waybar/                # Reference copies of patched waybar files
        ├── modules.json
        ├── launch.sh
        └── themes/ml4w-glass-center/
            ├── config
            └── config-niri
```

## Uninstall

To fully reverse the installation:

```bash
# Remove niri config
rm -rf ~/.config/niri

# Remove session files
rm ~/.local/bin/start-niri.sh
sudo rm /usr/share/wayland-sessions/niri.desktop

# Restore waybar backups (if created by installer)
# Check for .bak files in ~/.config/waybar/
ls ~/.config/waybar/*.bak* ~/.config/waybar/themes/ml4w-glass-center/*.bak* 2>/dev/null

# Remove niri/workspaces from modules.json and theme config
# (or restore from .bak files)

# Uninstall packages (optional — only if nothing else uses them)
sudo pacman -Rns niri swayidle swaylock xwayland-satellite
```
