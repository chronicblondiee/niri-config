# Niri Standalone Configuration

Standalone [niri](https://github.com/YaLTeR/niri) scrollable-tiling Wayland compositor configuration, primary target **openSUSE Tumbleweed/Slowroll** with [Noctalia](https://docs.noctalia.dev/) v5 as the desktop shell.

> **Legacy Arch support**: `install.sh`/`cleanup.sh` target Arch Linux + Noctalia **v4** (Quickshell-based) and are kept for reference only — they are not maintained against the current `config/` files, which use Noctalia v5's TOML config and IPC syntax. See [Legacy: Arch Linux](#legacy-arch-linux) below.

## Prerequisites

- openSUSE Tumbleweed or Slowroll (Noctalia v5 needs `sdbus-c++` >= 2.x, not available on Leap)
- SDDM display manager (installed by the installer if missing)
- Flatpak + Flathub, for zen-browser (installed by the installer if missing)

## Quick Install

```bash
git clone git@github.com:chronicblondiee/niri-config.git
cd niri-config
./install-opensuse.sh
```

The installer is interactive and idempotent — every step asks for confirmation and creates `.bak` backups before modifying files. It handles:

1. **Broken symlink cleanup** — scans `~/.config` for dead links from old setups
2. **Repository setup** — adds the `home:neifua:Noctalia` OBS repo (and `KDE:Frameworks` as a fallback for `polkit-kde-agent-6`)
3. **Package installation** — official oss repo via `zypper`, Noctalia via OBS, zen-browser via Flatpak/Flathub, Catppuccin SDDM theme via git clone
4. **Config deployment** — niri, Noctalia v5, kitty, fish, GTK dark theme, Catppuccin cursor theme via GitHub release zip
5. **Directory setup** — `~/Pictures/Wallpapers/` and `~/Pictures/Screenshots/`
6. **Keyboard layout** — sets console + X11/Wayland layout to `ie` (Ireland) via `localectl`
7. **SSH agent** — enables `ssh-agent.socket`, disables conflicting agents (gnome-keyring, kwallet, gcr)
8. **Service cleanup** — masks conflicting notification daemons (swaync, dunst, mako)
9. **XDG portals** — configures `xdg-desktop-portal-gnome`, removes conflicting backends
10. **Default shell** — sets fish via `chsh` (adding it to `/etc/shells` if needed)
11. **Session environment** — installs `~/.config/environment.d/10-niri-cursor.conf` (`XCURSOR_PATH`), and cleans up the retired `start-niri.sh` wrapper if an older run installed one
12. **SDDM** — installs/enables SDDM, sets `graphical.target`, configures the Catppuccin Mocha theme, and forces `niri.desktop` as SDDM's remembered/preselected session (openSUSE's minimal-X install already logged in once with IceWM before you ran this, so SDDM would otherwise keep defaulting back to it)
13. **Validation** — runs `niri validate`

After installing, reboot — SDDM should now boot straight into Niri. If it still lands on the old desktop, pick **Niri** from the session picker manually once (bottom-left icon on the login screen) and it'll stick from then on.

A few Noctalia keybindings in `config.kdl` are best-effort translations from v4. The emoji-picker prefix (`/emo`) is now confirmed correct — it matches `shell.launcher.providers.emoji.prefix` in the real v5 settings schema (checked via `noctalia config export full`). The Control Center tab-jump tokens (notification history, network panel, calendar) are still unverified, since `noctalia msg` requires a running graphical session to query — check them with `noctalia msg --help` after logging in and adjust if needed.

### Post-install cleanup

Once you've confirmed Niri boots and logs in correctly, run `./cleanup-opensuse-default-desktop.sh` to remove openSUSE's default minimal-X fallback desktop (IceWM and its packages) plus any now-orphaned dependencies. It deliberately leaves `xorg-x11-server`/`xinit` alone, since SDDM's login greeter still runs under X11 by default on this system — removing them would break the login screen itself, not just the old desktop.

## Legacy: Arch Linux

`install.sh` + `cleanup.sh` still work for Arch Linux + Noctalia v4 as of when they were last touched, but they are **not** kept in sync with `config/niri/config.kdl` or `config/noctalia/config.toml`, which now target openSUSE + Noctalia v5. If you need the Arch/v4 setup, check out an earlier commit rather than relying on the current `config/` tree with these scripts.

```bash
./cleanup.sh   # remove Hyprland/Sway/ML4W leftovers (Arch only)
./install.sh   # Arch/pacman/AUR installer (Noctalia v4, unmaintained)
```

## Manual Install

### 1. Add repositories and install packages

```bash
# Noctalia v5 (OBS repo)
sudo zypper addrepo --refresh --name noctalia-v5 \
    https://download.opensuse.org/repositories/home:neifua:Noctalia/openSUSE_Tumbleweed/home:neifua:Noctalia.repo
sudo zypper --gpg-auto-import-keys refresh

# Official oss repo
sudo zypper install niri xwayland-satellite xdg-desktop-portal-gnome \
    kitty fish nautilus wl-clipboard cliphist lxqt-openssh-askpass openssh \
    gamemode gamemoded libgamemode0-32bit libgamemodeauto0-32bit gamescope \
    sddm noctalia

# polkit-kde-agent-6 (add KDE:Frameworks only if the bare install fails)
sudo zypper install polkit-kde-agent-6 || {
    sudo zypper addrepo --refresh https://download.opensuse.org/repositories/KDE:Frameworks/openSUSE_Tumbleweed/KDE:Frameworks.repo
    sudo zypper --gpg-auto-import-keys refresh
    sudo zypper install polkit-kde-agent-6
}

# zen-browser (Flatpak — no native package; --user avoids needing polkit's
# system-wide Deploy authorization, which has no agent in a plain terminal/SSH session)
flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub app.zen_browser.zen

# Catppuccin SDDM theme (no OBS package — install from source)
git clone --depth 1 https://github.com/catppuccin/sddm.git /tmp/catppuccin-sddm
sudo cp -r /tmp/catppuccin-sddm/src/catppuccin-mocha-mauve /usr/share/sddm/themes/
```

| Package | Purpose | Source |
|---------|---------|--------|
| `niri` | Scrollable-tiling Wayland compositor | oss repo |
| `noctalia` | Desktop shell v5 (bar, notifications, wallpaper, lock screen) | OBS `home:neifua:Noctalia` |
| `xwayland-satellite` | X11 app compatibility for niri | oss repo |
| `xdg-desktop-portal-gnome` | Screen sharing, file dialogs | oss repo |
| `kitty` | Terminal emulator | oss repo |
| `fish` | Fish shell | oss repo |
| `nautilus` | File manager | oss repo |
| `wl-clipboard` + `cliphist` | Clipboard history | oss repo |
| `polkit-kde-agent-6` | Polkit authentication prompts | oss repo, fallback `KDE:Frameworks` |
| `lxqt-openssh-askpass` | SSH key passphrase GUI prompt | oss repo |
| `gamemode` / `gamemoded` | Opt-in game performance optimization client and daemon | oss repo |
| `libgamemode0-32bit` / `libgamemodeauto0-32bit` | 32-bit GameMode client libraries for Steam/Proton games | oss repo |
| `gamescope` | Opt-in gaming micro-compositor for scaling, frame limiting, and fullscreen isolation | oss repo |
| `sddm` / `sddm-qt6` | Display manager | oss repo |
| Catppuccin SDDM theme | Login theme | manual, [catppuccin/sddm](https://github.com/catppuccin/sddm) |
| `app.zen_browser.zen` | Web browser | Flathub |

GameMode remains opt-in per game. In Steam, set a game's launch options to:

```text
gamemoderun %command%
```

This asks `gamemoded` to apply temporary performance optimizations while that game is
running; the installer does not modify Steam or wrap games globally. The installer also
offers to add the installing user to the package-created `gamemode` group so governor and
priority controls work; that new group membership requires a fresh login.

Gamescope is also opt-in per game. To combine fullscreen Gamescope isolation with
GameMode, use this Steam launch option:

```text
gamescope -f -- gamemoderun %command%
```

For games that need it, Gamescope also supports `-w`/`-h` for the game resolution,
`-W`/`-H` for the output resolution, `-r` for a frame-rate limit, and `-F fsr` for
FSR upscaling. Do not wrap Steam or every game globally; use these controls only when
a specific game benefits from them. Niri enables outer-display VRR on demand for
Gamescope and Steam game windows on either configured monitor.

### 2. Install configs

```bash
# Niri config
mkdir -p ~/.config/niri
cp config/niri/config.kdl ~/.config/niri/config.kdl

# Noctalia v5 config (replace __HOME__ with your home directory)
mkdir -p ~/.config/noctalia
sed "s|__HOME__|$HOME|g" config/noctalia/config.toml > ~/.config/noctalia/config.toml

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
# Keyboard layout (console + X11/Wayland)
sudo localectl set-x11-keymap ie
sudo localectl set-keymap ie

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
sudo zypper remove xdg-desktop-portal-hyprland xdg-desktop-portal-wlr 2>/dev/null || true

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
grep -qx /usr/bin/fish /etc/shells || echo /usr/bin/fish | sudo tee -a /etc/shells
chsh -s /usr/bin/fish
```

### 4. Install session environment

The niri package's own `/usr/share/wayland-sessions/niri.desktop` is used as-is — don't override
it, since a package update reinstalls the file and silently drops any customization. Session-wide
environment goes in `environment.d` instead, which the systemd user manager reads before starting
`niri.service`.

```bash
mkdir -p ~/.config/environment.d
sed "s|__HOME__|$HOME|g" config/environment.d/10-niri-cursor.conf \
    > ~/.config/environment.d/10-niri-cursor.conf

# Enable SDDM
sudo systemctl enable sddm.service
sudo systemctl set-default graphical.target

# SDDM Catppuccin theme (requires sudo) — openSUSE uses conf.d drop-ins
sudo mkdir -p /etc/sddm.conf.d
printf '[Theme]\nCurrent=catppuccin-mocha-mauve\n' | sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null
```

### 5. Validate

```bash
niri validate
```

## Components

| Component | Tool |
|-----------|------|
| Compositor | niri |
| Bar | Noctalia v5 |
| App launcher | Noctalia v5 |
| Notifications | Noctalia v5 |
| Wallpaper | Noctalia v5 |
| Clipboard | Noctalia v5 (native clipboard history) |
| Terminal | kitty |
| Power/session menu | Noctalia v5 |
| Lock screen | Noctalia v5 |
| X11 compat | xwayland-satellite |
| Gaming | GameMode + opt-in Gamescope; on-demand VRR on both displays |
| SSH agent | systemd ssh-agent.socket + lxqt-openssh-askpass |
| Login theme | Catppuccin Mocha (manual install, no OBS package) |
| Cursor theme | Catppuccin Mocha Mauve (manual install, no OBS package) |

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
| `Super+Ctrl+A` | Calendar (Control Center tab)¹ |
| `Super+Ctrl+I` | Network panel (Control Center tab)¹ |
| `Super+N` | Notification history (Control Center tab)¹ |
| `Super+Shift+N` | Toggle Do Not Disturb |
| `Super+Shift+B` | Toggle bar |
| `Super+D` | Toggle dock |
| `Super+Shift+W` | Random wallpaper |
| `Super+Ctrl+W` | Wallpaper picker |
| `Super+Ctrl+D` | Toggle dark mode |
| `Super+Ctrl+N` | Toggle night light |
| `Super+Shift+M` | Media panel |
| Media keys | Volume, brightness, player controls (with OSD) |

¹ Noctalia v5 moved these into Control Center tabs instead of standalone panels (v4 behavior). The exact tab-jump IPC token wasn't verified against a running instance — check with `noctalia msg --help` and adjust `config.kdl` if the binding doesn't land on the right tab. Calendar and weather are also now separate features/tabs in v5, no longer a combined widget.

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

### Current setup

This repo's `config.kdl` hardcodes the actual fixed hardware rather than relying on auto-detection (which only ever configured the first-detected output — the second monitor was silently dropped):

```kdl
// Acer VG270U P 27" 1440p/144Hz — left
output "DP-2" {
    mode "2560x1440@143.995"
    position x=0 y=0
    scale 1.0
}

// Gigabyte MO34WQC2 34" ultrawide — right, primary
output "DP-1" {
    mode "3440x1440@239.991"
    position x=2560 y=0
    scale 1.0
    focus-at-startup
}
```

Position values are in logical (scaled) pixels — with `scale 1.0` on both, that's the same as physical pixels here. Use `niri msg outputs` to check logical vs physical sizes when calculating positions for a different scale.

### Tips

- Explicit `position`/`mode` on every output beats letting niri auto-place them — automatic placement is fine for a single monitor, but is easy to get wrong (or have silently dropped, as happened here) with two or more
- Set `scale 1.0` explicitly to prevent niri from auto-scaling on HiDPI panels
- Available modes are listed in `niri msg outputs` — use the exact `WxH@rate` string, matching to the 3 decimal digits
- `focus-at-startup` on an output picks which monitor gets initial focus (i.e. your "primary")
- Changes take effect immediately on save (no restart needed)

## Repo Structure

```
├── README.md
├── CLAUDE.md
├── install-opensuse.sh
├── cleanup-opensuse-default-desktop.sh
├── install.sh       (legacy, Arch)
├── cleanup.sh       (legacy, Arch)
├── config/
│   ├── niri/
│   │   └── config.kdl
│   ├── noctalia/
│   │   └── config.toml
│   ├── kitty/
│   │   └── kitty.conf
│   ├── fish/
│   │   └── config.fish
│   ├── gtk-3.0/
│   │   └── settings.ini
│   ├── gtk-4.0/
│   │   └── settings.ini
│   └── environment.d/
│       └── 10-niri-cursor.conf
```

## Wallpapers

Catppuccin Mocha wallpapers from [orangci/walls-catppuccin-mocha](https://github.com/orangci/walls-catppuccin-mocha) — 330+ images color-matched to the Mocha palette. Place them in `~/Pictures/Wallpapers/` and cycle with `Super+Shift+W` (random) or `Super+Ctrl+W` (picker).

## Uninstall

```bash
# Remove configs
rm -rf ~/.config/niri ~/.config/noctalia ~/.config/xdg-desktop-portal/niri-portals.conf

# Remove session environment (leave /usr/share/wayland-sessions/niri.desktop
# alone — it belongs to the niri package and goes away with it)
rm ~/.config/environment.d/10-niri-cursor.conf

# Restore default shell
chsh -s /bin/bash

# Disable SSH agent
systemctl --user disable ssh-agent.socket

# Uninstall packages (optional)
sudo zypper remove niri xwayland-satellite xdg-desktop-portal-gnome lxqt-openssh-askpass noctalia polkit-kde-agent-6 gamescope
flatpak uninstall app.zen_browser.zen
sudo rm -rf /usr/share/sddm/themes/catppuccin-mocha-mauve /etc/sddm.conf.d/10-theme.conf
sudo zypper removerepo noctalia-v5
```
