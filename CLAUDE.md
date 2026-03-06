# CLAUDE.md

## Project

Standalone niri compositor configuration for Arch Linux. The installer (`install.sh`) is interactive, idempotent, and creates backups before modifying files. Handles both clean installs and systems with existing compositor setups (Hyprland, Sway, ML4W).

## Key Files

- `install.sh` — Main installer script (bash, interactive)
- `cleanup.sh` — Removes old Hyprland/ML4W/Sway dependencies, services, and configs
- `config/niri/config.kdl` — Niri compositor config (KDL format)
- `config/noctalia/settings.json` — Noctalia-shell settings (`__HOME__` placeholder replaced at install time)
- `config/kitty/kitty.conf` — Kitty terminal config (Catppuccin Mocha)
- `config/fish/config.fish` — Fish shell config (SSH agent, Wayland env vars, aliases)
- `config/gtk-3.0/settings.ini` — GTK3 dark theme settings
- `config/gtk-4.0/settings.ini` — GTK4 dark theme settings
- `sessions/start-niri.sh` — Session startup wrapper called by SDDM
- `sessions/niri.desktop` — SDDM wayland session entry (`/home/brown` replaced with `$HOME` at install time)

## Architecture

- Fully standalone: no dependency on ML4W or Hyprland
- Desktop shell: noctalia-shell (bar, notifications, wallpaper, lock screen, launcher, clipboard)
- SSH auth: systemd ssh-agent.socket + lxqt-openssh-askpass (replaces gnome-keyring, kwallet)
- XDG portals: xdg-desktop-portal-gnome via niri-portals.conf
- Niri-specific: xwayland-satellite (X11 compat)

## Installer Steps

1. Check prerequisites (Arch-based system)
1b. Detect old compositors (hyprland, sway) and offer cleanup
1c. Clean up broken symlinks in ~/.config
2. Install packages (pacman + AUR)
3. Copy configs (niri, noctalia, kitty, fish, GTK)
3e. Create wallpaper + screenshot directories
3f. Enable systemd ssh-agent.socket, disable gcr-ssh-agent
3g. Disable conflicting services (swaync, dunst, mako, gnome-keyring, kwallet)
3h. Configure XDG desktop portal (niri-portals.conf), remove conflicting portal backends
3i. Set fish as default shell via chsh
4. Install session files (start-niri.sh, niri.desktop, SDDM Catppuccin theme)
5. Validate niri config

## Conventions

- Installer steps should be idempotent (skip if already done)
- Always confirm before overwriting user files
- Create `.bak` backups before modifying existing configs
- The `output` section in config.kdl is auto-detected at install time via niri or DRM sysfs fallback
- SDDM config updates use sed to preserve existing sections (e.g. autologin)
- Keybindings use `hotkey-overlay-title` to show descriptions in the niri hotkey overlay
