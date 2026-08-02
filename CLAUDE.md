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
- `config/environment.d/10-niri-cursor.conf` — Session-wide `XCURSOR_PATH` workaround, read by the systemd user manager (`__HOME__` placeholder replaced with `$HOME` at install time). The SDDM session entry is the packaged `/usr/share/wayland-sessions/niri.desktop`; this repo no longer overrides it

## Architecture

- Fully standalone: no dependency on ML4W or Hyprland
- Desktop shell: Noctalia v5 (bar, notifications, wallpaper, lock screen, launcher, clipboard — built directly on Wayland/OpenGL ES, no Qt/GTK/Quickshell)
- SSH auth: systemd ssh-agent.socket + lxqt-openssh-askpass (replaces gnome-keyring, kwallet)
- XDG portals: `xdg-desktop-portal-gnome` (default and screencasting), `xdg-desktop-portal-gtk` (Access and Notification), and `gnome-keyring` (Secret), routed via Niri's upstream `niri-portals.conf`
- Do not export `GDK_BACKEND` globally. Niri's GNOME screencast portal requires GTK to choose its backend per process.
- Niri-specific: xwayland-satellite (X11 compat)
- Package sources: openSUSE oss repo for most packages, including the complete GNOME/GTK/gnome-keyring portal set; OBS `home:neifua:Noctalia` for `noctalia`; Flatpak/Flathub for `zen-browser` (no native package) and Vesktop; manual GitHub-release-zip install for the Catppuccin SDDM theme and cursor theme (no OBS package for either)
- Gaming: GameMode daemon, native and 32-bit client libraries, and Gamescope come from the openSUSE oss repo. GameMode activation stays opt-in per Steam game with `gamemoderun %command%`; Gamescope is also per-game with `gamescope -f -- gamemoderun %command%` (never wrap Steam or all games globally). The installer offers to add its invoking user to the package-created `gamemode` group; a fresh login is required after accepting. Both fixed outputs use on-demand VRR, enabled only by the `gamescope`/`steam_app_` window rule.

## Installer Steps (`install-opensuse.sh`)

1. Check prerequisites (zypper present, Tumbleweed/Slowroll via /etc/os-release)
1b. Clean up broken symlinks in ~/.config
2. Add repositories (`home:neifua:Noctalia`, `KDE:Frameworks` fallback for polkit-kde-agent-6)
3. Install packages (zypper), including the GNOME/GTK/gnome-keyring portal providers, GameMode, its 32-bit Steam/Proton libraries, and Gamescope, + noctalia + polkit-kde-agent-6
3a. Install zen-browser and Vesktop (flatpak/Flathub), forcing Vesktop to native Wayland by denying X11 sockets
3b. Install Catppuccin SDDM theme (git clone into /usr/share/sddm/themes/)
3c–3g. Copy configs (niri, noctalia, kitty, fish, GTK)
3g2. Install Catppuccin Mocha Mauve cursor theme (GitHub release zip into ~/.local/share/icons/)
3h. Create wallpaper/screenshot dirs
3i. Set system keyboard layout via localectl
3j. Enable systemd ssh-agent.socket, disable gcr-ssh-agent
3k. Disable conflicting services (swaync, dunst, mako, gnome-keyring, kwallet)
3l. Configure XDG desktop portal (niri-portals.conf), remove conflicting portal backends
3m. Set fish as default shell via chsh (ensuring the path is in /etc/shells)
4. Install session environment (`~/.config/environment.d/10-niri-cursor.conf`), and clean up the retired `start-niri.sh` wrapper / its `/usr/share/wayland-sessions/niri.desktop` override if an older run left them behind
4a. Install and configure SDDM (service enable, graphical.target, Catppuccin theme drop-in, forces niri.desktop as SDDM's remembered/preselected session via /var/lib/sddm/state.conf)
5. Validate niri config

## Post-install cleanup (`cleanup-opensuse-default-desktop.sh`)

Separate, opt-in script — run only after confirming Niri boots/logs in correctly. Checks `/var/lib/sddm/state.conf` for `Session=niri.desktop` as a safety gate before proceeding. Removes IceWM packages (openSUSE minimal-X's default fallback desktop), dangling xsession `default.desktop`/alternatives symlinks left behind, and offers to remove orphaned packages (`zypper packages --orphaned`). Does NOT remove `xorg-x11-server`/`xinit`/the x11 patterns — SDDM's login greeter runs under X11 by default on this system (confirmed via `systemctl status sddm` showing an `Xorg.bin` child process), so removing Xorg would break the login screen itself, not just the old desktop.

## Conventions

- Installer steps should be idempotent (skip if already done)
- Always confirm before overwriting user files
- Create `.bak` backups before modifying existing configs
- The `output` section in config.kdl is hardcoded for this machine's fixed two-monitor hardware (Acer VG270U P 27" 1440p/144Hz on DP-2, Gigabyte MO34WQC2 34" ultrawide on DP-1) — no longer auto-detected at install time. The previous auto-detect (niri/DRM sysfs) only ever picked the *first* connected output, silently dropping the second monitor; since the hardware doesn't change between installs (same machine), explicit `position`/`mode` per output is more correct than relying on niri's automatic layout. Refresh rates must match `niri msg outputs` to the exact 3 decimal digits, and connector names (DP-1/DP-2) assume cables stay in the same GPU ports
- SDDM theme config is a drop-in at `/etc/sddm.conf.d/10-theme.conf` (openSUSE splits SDDM config across `/etc/sddm.conf.d/*.conf` rather than one monolithic file)
- Keybindings use `hotkey-overlay-title` to show descriptions in the niri hotkey overlay
- `config/noctalia/config.toml` has been validated against a real installed noctalia v5.0.0 via `noctalia config validate`/`export full` (zero warnings) — if you change it, re-validate the same way rather than guessing key names, since the schema doesn't match v4's settings.json field names
- A few Noctalia v5 IPC bindings in config.kdl are still best-effort guesses, not verified against a running instance (Control Center tab-jump tokens for network/calendar/notification-history) — flagged inline with comments; `noctalia msg` requires an active graphical session to query `--help`, so verify on real hardware before trusting them. The emoji-picker prefix is confirmed correct (matches `shell.launcher.providers.emoji.prefix` in the schema)
- openSUSE's minimal-X pattern install already logs in once with IceWM before this repo's installer ever runs, which leaves `~sddm/state.conf`'s `[Last] Session=` pointing at IceWM — installing `niri.desktop` alone isn't enough to make a plain login land on Niri; `install-opensuse.sh` step 4a overwrites that state file directly (confirmed via `man sddm-state.conf`: the file only ever holds `[Last] Session=`/`User=`, so a full overwrite is safe, not a surgical edit)
- Cursor theme is Catppuccin Mocha Mauve (`catppuccin/cursors` GitHub release, same accent as the SDDM theme), size 18. Set in three places, all of which must stay in sync: `config.kdl`'s top-level `cursor { xcursor-theme ...; xcursor-size 18; }` block, GTK 3.0/4.0 settings.ini, and — critically — GSettings (`gsettings set org.gnome.desktop.interface cursor-theme/cursor-size`). The GSettings copy is the one that actually matters for most GTK/Qt apps: this repo's portal backend is `xdg-desktop-portal-gnome`, and portal-aware apps query it for interface settings via the `org.gnome.desktop.interface` schema, ignoring niri's XCURSOR env and the local settings.ini entirely. Confirmed by observation: setting only the KDL block + settings.ini left `gsettings get org.gnome.desktop.interface cursor-theme/cursor-size` still at the defaults (`'Adwaita'`/`24`), and apps kept showing the old cursor even after a full logout/login — only setting GSettings directly fixed it. Also confirmed: niri's cursor manager does NOT reinitialize on `niri msg action load-config-file`, so KDL-side cursor changes need a full niri restart (logout/login) regardless. Size 18 (not 16) because this theme's XCursor files only bake in exact nominal sizes in multiples of 6 (12, 18, 24...) — niri's cursor loader (`load_xcursor` in niri's `src/cursor.rs`) actually does nearest-size matching, not exact, so size wasn't really the blocker; see the next bullet for the real cause
- Dark mode has the same portal gap as the cursor theme (previous bullet): GTK 3.0/4.0 `settings.ini` sets `gtk-application-prefer-dark-theme=1`/`gtk-theme-name=Adwaita-dark`, but GTK4/libadwaita apps and modern Qt6 apps don't read that file — they query dark-mode state from the `org.freedesktop.appearance` portal setting, which `xdg-desktop-portal-gnome` backs with GSettings (`org.gnome.desktop.interface color-scheme`/`gtk-theme`), not the local settings.ini. Confirmed by observation: settings.ini was already correctly dark, but `gsettings get org.gnome.desktop.interface color-scheme` was still `'default'` and `gtk-theme` was `'Adwaita'` — GTK4/Qt6/portal-aware apps (e.g. zen-browser) could render light despite everything else being dark. Fixed by `gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'` + `gtk-theme 'Adwaita-dark'`, applied live in the installer right after the cursor-theme GSettings sync (no relogin required, unlike the cursor fix)
- The Catppuccin cursor theme silently failed to load at all (any size), logged as `WARN niri::cursor: error loading xcursor default@N: no default icon` in `journalctl --user`. Root cause is a real bug in the `xcursor` crate niri depends on (v0.3.10, `theme_search_paths()` in its `src/lib.rs`): when `$XDG_DATA_HOME` is set in the environment, the crate uses that path directly as a theme search dir instead of appending `icons/` to it (the `$XDG_DATA_DIRS` branch right below it does append `icons/` correctly — this looks like a one-line omission upstream). Since this session sets `XDG_DATA_HOME=$HOME/.local/share` explicitly, niri never even looked in `$HOME/.local/share/icons`, so user-installed cursor themes there were invisible to it regardless of theme/size config. Confirmed by reconstructing the crate's exact search-path logic in Python against this machine's real env vars — none of the resulting paths contained the theme dir. Fixed by setting `XCURSOR_PATH` explicitly (`$HOME/.local/share/icons:$HOME/.icons:/usr/share/icons:/usr/share/pixmaps`), which the crate checks first and uses as-is, bypassing the buggy `$XDG_DATA_HOME` branch entirely. This will affect any user-installed (non-system-package) Xcursor theme on this setup, not just Catppuccin
- `XCURSOR_PATH` lives in `~/.config/environment.d/10-niri-cursor.conf`, **not** in a session wrapper script. It was originally set in `sessions/start-niri.sh`, a wrapper installed over `/usr/share/wayland-sessions/niri.desktop` — and on 2026-08-02 the cursor silently reverted to Adwaita because the `niri-26.04-1.4` package update reinstalled that file. `wayland-sessions` entries are not marked `%config`, so rpm overwrites them with no `.rpmsave`, meaning *any* override of a packaged desktop entry is temporary by nature. With the packaged entry restored, SDDM ran `niri-session` directly (`ps` showed `sddm-helper … --start niri-session`), the wrapper never executed, and the xcursor bug above resurfaced. `environment.d` is the durable home for this: `niri-session` starts niri via `systemctl --user --wait start niri.service`, and the systemd user manager reads `~/.config/environment.d/*.conf` at startup, so the variable reaches niri regardless of which session entry launched it — and zypper can never touch a file under `$HOME`. The wrapper's other exports (`XDG_CURRENT_DESKTOP`, `XDG_SESSION_TYPE`, `XDG_SESSION_DESKTOP`) turned out to be redundant — sddm/niri-session already set all three, confirmed by reading `/proc/<niri-pid>/environ` — so the wrapper and its `.desktop` override were retired entirely rather than reinstated. Note `environment.d` is read only when the user manager starts, so changes need a full logout/login (which the cursor fix requires anyway, per the earlier bullet)
