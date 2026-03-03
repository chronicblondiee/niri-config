# CLAUDE.md

## Project

Standalone niri compositor configuration for Arch Linux. The installer (`install.sh`) is interactive, idempotent, and creates backups before modifying files.

## Key Files

- `install.sh` — Main installer script (bash, interactive)
- `config/niri/config.kdl` — Niri compositor config (KDL format)
- `config/swaylock/config` — OLED-friendly swaylock config (Catppuccin dark)
- `config/waybar/config` — Waybar bar layout (niri/workspaces in center)
- `config/waybar/modules.json` — All waybar module definitions (standalone, no ML4W deps)
- `config/waybar/quicklinks.json` — Quick-launch buttons (browser, file manager)
- `config/waybar/style.css` — Waybar theme (glass style with inlined colors)
- `config/waybar/launch.sh` — Waybar launcher (kill + restart, respects disabled state)
- `config/wlogout/layout` — Power menu layout (lock, logout, suspend, reboot, shutdown)
- `scripts/power.sh` — Power actions using swaylock + niri msg + systemctl
- `scripts/cliphist.sh` — Clipboard manager (cliphist + rofi)
- `scripts/toggle-waybar.sh` — Toggle waybar visibility
- `scripts/waypaper.sh` — Wallpaper selector wrapper
- `sessions/start-niri.sh` — Session startup wrapper called by SDDM
- `sessions/niri.desktop` — SDDM wayland session entry

## Architecture

- Fully standalone: no dependency on ML4W or Hyprland
- Shared tools: rofi, swaync, swww, cliphist, kitty, wlogout, waypaper
- Niri-specific: swayidle (idle), swaylock (lock), xwayland-satellite (X11 compat)
- All scripts live in `scripts/` and are installed to `~/.config/niri/scripts/`

## Conventions

- Installer steps should be idempotent (skip if already done)
- Always confirm before overwriting user files
- Create `.bak` backups before modifying existing configs
- The `output` section in config.kdl is auto-detected at install time via niri or DRM sysfs fallback
