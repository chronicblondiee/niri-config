# CLAUDE.md

## Project

Standalone niri compositor configuration for Arch Linux. The installer (`install.sh`) is interactive, idempotent, and creates backups before modifying files.

## Key Files

- `install.sh` — Main installer script (bash, interactive)
- `cleanup.sh` — Removes old Hyprland/ML4W dependencies
- `config/niri/config.kdl` — Niri compositor config (KDL format)
- `config/noctalia/settings.json` — Noctalia-shell settings
- `config/kitty/kitty.conf` — Kitty terminal config (Catppuccin Mocha)
- `config/fish/config.fish` — Fish shell config (Wayland env vars, aliases)
- `config/gtk-3.0/settings.ini` — GTK3 dark theme settings
- `config/gtk-4.0/settings.ini` — GTK4 dark theme settings
- `sessions/start-niri.sh` — Session startup wrapper called by SDDM
- `sessions/niri.desktop` — SDDM wayland session entry

## Architecture

- Fully standalone: no dependency on ML4W or Hyprland
- Desktop shell: noctalia-shell (bar, notifications, wallpaper, lock screen)
- Shared tools: cliphist, kitty
- Niri-specific: xwayland-satellite (X11 compat)

## Conventions

- Installer steps should be idempotent (skip if already done)
- Always confirm before overwriting user files
- Create `.bak` backups before modifying existing configs
- The `output` section in config.kdl is auto-detected at install time via niri or DRM sysfs fallback
