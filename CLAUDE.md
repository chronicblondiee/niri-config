# CLAUDE.md

## Project

Installer repo for running niri alongside Hyprland with ML4W dotfiles on Arch Linux. The installer (`install.sh`) is interactive, idempotent, and creates backups before modifying files.

## Key Files

- `install.sh` — Main installer script (bash, interactive)
- `config/niri/config.kdl` — Niri compositor config (KDL format)
- `config/waybar/modules-niri.json` — Waybar module snippet for niri workspace support
- `sessions/start-niri.sh` — Session startup wrapper called by SDDM
- `sessions/niri.desktop` — SDDM wayland session entry
- `dotfiles/waybar/` — Reference copies of the patched waybar files

## Architecture

- Niri and Hyprland share: waybar, rofi, swaync, swww, cliphist, kitty, wlogout
- Niri-specific: swayidle (idle), swaylock (lock), xwayland-satellite (X11 compat)
- Waybar portability: `launch.sh` detects `XDG_CURRENT_DESKTOP` and loads compositor-appropriate config
- The waybar theme has a `config-niri` variant that uses `niri/workspaces` instead of `hyprland/workspaces`

## Conventions

- Installer steps should be idempotent (skip if already done)
- Always confirm before overwriting user files
- Create `.bak` backups before modifying existing configs
- The `output` section in config.kdl is hardware-specific and must be edited per-machine
