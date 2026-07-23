# Architecture

This document explains how the Lin OS build pipeline works end-to-end.

## High-level flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          GitHub Actions runner                          │
│                       (ubuntu-latest, 2 CPU, 7 GB)                      │
└──────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
                ┌─────────────────────────────────┐
                │  archlinux:latest container     │
                │  (--privileged --cap-add=ALL)   │
                └─────────────────────────────────┘
                                  │
            ┌─────────────────────┼──────────────────────┐
            │                     │                      │
            ▼                     ▼                      ▼
   ┌─────────────────┐  ┌────────────────────┐  ┌─────────────────────┐
   │ 1. Build local   │  │ 2. Add chaotic-aur │  │ 3. Sanity-check      │
   │    packages:     │  │    repo + keyring  │  │    packages.x86_64  │
   │    lin-branding  │  │    to pacman.conf  │  │    against repos    │
   │    lin-welcome   │  │                    │  │                     │
   │    lin-defaults  │  │                    │  │                     │
   └────────┬────────┘  └─────────┬──────────┘  └──────────┬──────────┘
            │                     │                        │
            └─────────────────────┴────────────────────────┘
                                  │
                                  ▼
                ┌─────────────────────────────────┐
                │ 4. mkarchiso -v -w work/        │
                │    -o out/ .                    │
                │                                 │
                │   (a) Bootstraps airootfs from  │
                │       packages.x86_64           │
                │   (b) Runs /root/                │
                │       customize_airootfs.sh     │
                │       (creates user, enables    │
                │        services, sets up SDDM)  │
                │   (c) Squashes airootfs into    │
                │       squashfs (zstd-19)        │
                │   (d) Assembles ISO with        │
                │       syslinux + systemd-boot   │
                └────────────┬────────────────────┘
                             │
                             ▼
                ┌─────────────────────────────────┐
                │ 5. lin-YYYY.MM.DD-x86_64.iso    │
                │    + sha256sum.txt              │
                │    + md5sum.txt                 │
                └────────────┬────────────────────┘
                             │
                             ▼
                ┌─────────────────────────────────┐
                │ 6. Uploaded as Actions artifact │
                │    (14-day retention)            │
                │    + GitHub Release on tags      │
                └─────────────────────────────────┘
```

## Key files and their roles

| File | Role |
|---|---|
| `profiledef.sh` | archiso profile metadata — ISO name, version, boot modes, file perms |
| `packages.x86_64` | The list of packages installed in the live ISO's airootfs |
| `pacman.conf` | Repo config — core, extra, multilib, chaotic-aur, lin-local |
| `airootfs/` | Filesystem overlay — every file here is copied to `/` on the live ISO |
| `airootfs/root/customize_airootfs.sh` | Post-build hook — creates the `lin` user, enables services, configures SDDM |
| `airootfs/etc/skel/` | Skeleton home directory — copied to every new user's `$HOME` |
| `airootfs/etc/calamares/` | One-click installer config (the user-facing install wizard) |
| `packages/lin-branding/PKGBUILD` | Builds the GTK theme, SDDM theme, wallpaper, icons |
| `packages/lin-welcome/PKGBUILD` | Builds the welcome app, store launcher, updater |
| `packages/lin-defaults/PKGBUILD` | Builds the Hyprland/waybar/wofi/kitty configs into a package |
| `scripts/build-lin-packages.sh` | Builds all three local packages in CI |
| `.github/workflows/build-iso.yml` | The CI pipeline |

## Runtime architecture (what runs on the user's machine)

After install, the user's system runs:

```
┌─────────────────────────────────────────────────────────┐
│                    User applications                    │
│  Firefox, Thunar, Kitty, Steam, Games, Bauh store...    │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│             Hyprland (Wayland compositor)               │
│   - Native blur + rounded corners + animations          │
│   - Multi-monitor, virtual desktops, gestures           │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│              XDG Desktop Portal (Hyprland)              │
│        (screen share, file picker, screencast)          │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│          PipeWire (audio) + WirePlumber (policy)        │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│               NetworkManager + BlueZ + IWD              │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    systemd + kernel                     │
│            (with TLP power management)                  │
└─────────────────────────────────────────────────────────┘
```

## Performance budget

| Component | Idle RAM |
|---|---|
| Linux kernel + systemd | ~30 MB |
| Hyprland compositor | ~80 MB |
| waybar | ~15 MB |
| Hyprpaper + hypridle + hyprlock | ~10 MB |
| PipeWire + WirePlumber | ~8 MB |
| NetworkManager | ~8 MB |
| SDDM (after login) | ~5 MB |
| **Total target** | **~150 MB** |

This is significantly less than KDE Plasma (~600 MB) or GNOME (~700 MB) at idle,
while still offering a modern, GPU-accelerated, animated Wayland desktop.
