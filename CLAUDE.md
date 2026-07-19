# CLAUDE.md

## Project

Standalone niri compositor configuration, primary target **openSUSE Tumbleweed/Slowroll** (installer `install-opensuse.sh`, zypper + OBS repos). Uses **Noctalia v5** (native C++/OpenGL ES shell, no Qt/GTK/Quickshell dependency, TOML config, `noctalia msg <verb>` IPC).

`install.sh`/`cleanup.sh` are **legacy** — they target Arch Linux (`pacman`/AUR) and Noctalia **v4** (Quickshell/QML, JSON config, `qs ipc call <target> <action>` IPC). They're kept for reference only and are not maintained against the current `config/` files, which have moved to v5/openSUSE syntax.

The current installer (`install-opensuse.sh`) is interactive, idempotent, and creates backups before modifying files.

## Key Files

- `install-opensuse.sh` — Main installer script (bash, interactive, zypper-based)
- `cleanup-opensuse-default-desktop.sh` — Post-install script: removes openSUSE's default IceWM fallback desktop + orphaned deps once Niri is confirmed working; deliberately leaves xorg-x11-server/xinit alone (SDDM's greeter still runs under X11)
- `install.sh`, `cleanup.sh` — Legacy Arch/pacman/AUR installer + cleanup (Noctalia v4, unmaintained)
- `config/niri/config.kdl` — Niri compositor config (KDL format); Noctalia binds use v5's `noctalia msg <verb>` IPC
- `config/noctalia/config.toml` — Noctalia v5 shell settings (TOML; `__HOME__` placeholder replaced at install time)
- `config/kitty/kitty.conf` — Kitty terminal config (Catppuccin Mocha)
- `config/fish/config.fish` — Fish shell config (SSH agent, Wayland env vars, aliases)
- `config/gtk-3.0/settings.ini` — GTK3 dark theme settings
- `config/gtk-4.0/settings.ini` — GTK4 dark theme settings
- `sessions/start-niri.sh` — Session startup wrapper called by SDDM
- `sessions/niri.desktop` — SDDM wayland session entry (`__HOME__` placeholder replaced with `$HOME` at install time)

## Architecture

- Fully standalone: no dependency on ML4W or Hyprland
- Desktop shell: Noctalia v5 (bar, notifications, wallpaper, lock screen, launcher, clipboard — built directly on Wayland/OpenGL ES, no Qt/GTK/Quickshell)
- SSH auth: systemd ssh-agent.socket + lxqt-openssh-askpass (replaces gnome-keyring, kwallet)
- XDG portals: xdg-desktop-portal-gnome via niri-portals.conf
- Niri-specific: xwayland-satellite (X11 compat)
- Package sources: openSUSE oss repo for most packages; OBS `home:neifua:Noctalia` for `noctalia`; Flatpak/Flathub for `zen-browser` (no native package); manual git-clone install for the Catppuccin SDDM theme (no OBS package)

## Installer Steps (`install-opensuse.sh`)

1. Check prerequisites (zypper present, Tumbleweed/Slowroll via /etc/os-release)
1b. Clean up broken symlinks in ~/.config
2. Add repositories (`home:neifua:Noctalia`, `KDE:Frameworks` fallback for polkit-kde-agent-6)
3. Install packages (zypper) + noctalia + polkit-kde-agent-6
3a. Install zen-browser (flatpak/Flathub)
3b. Install Catppuccin SDDM theme (git clone into /usr/share/sddm/themes/)
3c–3h. Copy configs (niri, noctalia, kitty, fish, GTK), create wallpaper/screenshot dirs
3i. Set system keyboard layout via localectl
3j. Enable systemd ssh-agent.socket, disable gcr-ssh-agent
3k. Disable conflicting services (swaync, dunst, mako, gnome-keyring, kwallet)
3l. Configure XDG desktop portal (niri-portals.conf), remove conflicting portal backends
3m. Set fish as default shell via chsh (ensuring the path is in /etc/shells)
4. Install session files (start-niri.sh, niri.desktop)
4a. Install and configure SDDM (service enable, graphical.target, Catppuccin theme drop-in, forces niri.desktop as SDDM's remembered/preselected session via /var/lib/sddm/state.conf)
5. Validate niri config

## Post-install cleanup (`cleanup-opensuse-default-desktop.sh`)

Separate, opt-in script — run only after confirming Niri boots/logs in correctly. Checks `/var/lib/sddm/state.conf` for `Session=niri.desktop` as a safety gate before proceeding. Removes IceWM packages (openSUSE minimal-X's default fallback desktop), dangling xsession `default.desktop`/alternatives symlinks left behind, and offers to remove orphaned packages (`zypper packages --orphaned`). Does NOT remove `xorg-x11-server`/`xinit`/the x11 patterns — SDDM's login greeter runs under X11 by default on this system (confirmed via `systemctl status sddm` showing an `Xorg.bin` child process), so removing Xorg would break the login screen itself, not just the old desktop.

## Conventions

- Installer steps should be idempotent (skip if already done)
- Always confirm before overwriting user files
- Create `.bak` backups before modifying existing configs
- The `output` section in config.kdl is auto-detected at install time via niri or DRM sysfs fallback
- SDDM theme config is a drop-in at `/etc/sddm.conf.d/10-theme.conf` (openSUSE splits SDDM config across `/etc/sddm.conf.d/*.conf` rather than one monolithic file)
- Keybindings use `hotkey-overlay-title` to show descriptions in the niri hotkey overlay
- `config/noctalia/config.toml` has been validated against a real installed noctalia v5.0.0 via `noctalia config validate`/`export full` (zero warnings) — if you change it, re-validate the same way rather than guessing key names, since the schema doesn't match v4's settings.json field names
- A few Noctalia v5 IPC bindings in config.kdl are still best-effort guesses, not verified against a running instance (Control Center tab-jump tokens for network/calendar/notification-history) — flagged inline with comments; `noctalia msg` requires an active graphical session to query `--help`, so verify on real hardware before trusting them. The emoji-picker prefix is confirmed correct (matches `shell.launcher.providers.emoji.prefix` in the schema)
- openSUSE's minimal-X pattern install already logs in once with IceWM before this repo's installer ever runs, which leaves `~sddm/state.conf`'s `[Last] Session=` pointing at IceWM — installing `niri.desktop` alone isn't enough to make a plain login land on Niri; `install-opensuse.sh` step 4a overwrites that state file directly (confirmed via `man sddm-state.conf`: the file only ever holds `[Last] Session=`/`User=`, so a full overwrite is safe, not a surgical edit)
