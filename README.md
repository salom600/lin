# Lin OS

> Lightweight, sleek, user-friendly Linux for Windows migrants.

[![Build ISO](https://github.com/salom600/lin/actions/workflows/build-iso.yml/badge.svg?branch=main)](https://github.com/salom600/lin/actions/workflows/build-iso.yml)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)

Lin OS is a custom Linux distribution built on top of Arch Linux with three
goals, in priority order:

1. **Lightweight** — ~150 MB RAM at idle, 0% CPU when nothing's running.
2. **Sleek & modern** — Windows 11-style UI with native transparency, blur,
   rounded corners, and smooth animations powered by Hyprland (Wayland).
3. **User-friendly for Windows migrants** — one-click installer (Calamares),
   unified app store (Bauh — pacman + AUR + Flatpak + AppImage), and a panel
   layout familiar to anyone coming from Windows 11.

---

## Why Arch Linux as the base?

After researching the main candidates:

| Distro | Idle RAM | Gaming support | Verdict |
|---|---|---|---|
| Alpine | ~50 MB | ❌ (musl breaks Steam/Proton) | Too minimal |
| Tiny Core | ~16 MB | ❌ | Way too minimal |
| **Arch** | ~150–250 MB | ✅ (native glibc, AUR, Steam/Proton) | **Best fit** |
| Debian minimal | ~120 MB | ⚠️ (older packages) | OK but worse tooling |
| Void | ~100 MB | ⚠️ (smaller repo) | Niche |

Arch wins because:
- **glibc** → Steam, Proton, and proprietary games work out of the box.
- **AUR** → the largest package repository in the Linux world.
- **archiso** → first-class tooling for building custom live ISOs.
- **rolling release** → users get fresh software without reinstalls.
- **transparent CI** → archiso runs in a container, perfect for GitHub Actions.

---

## Project layout

```
lin/                                  # repo root
├── .github/workflows/build-iso.yml   # CI: builds the ISO in an archlinux container
├── profiledef.sh                     # archiso profile metadata
├── packages.x86_64                   # the package list (everything installed in the ISO)
├── pacman.conf                       # pacman config (with chaotic-aur + local lin-local repo)
├── syslinux/syslinux.cfg             # BIOS boot config
├── efiboot/efiboot.cfg               # UEFI boot config
├── airootfs/                         # filesystem overlay (becomes / on the live ISO)
│   ├── etc/
│   │   ├── os-release                # Lin OS identity
│   │   ├── skel/.config/             # Hyprland / waybar / wofi / kitty / GTK / bauh configs
│   │   ├── calamares/                # one-click installer config + Lin branding
│   │   ├── lin/                      # first-boot / store / welcome scripts
│   │   └── systemd/system/           # lin-firstboot.service, lin-welcome.service
│   └── root/customize_airootfs.sh    # post-build hook (creates user, enables services)
├── packages/                         # three locally-built packages
│   ├── lin-branding/PKGBUILD         #   wallpaper, GTK theme, SDDM theme, icons
│   ├── lin-welcome/PKGBUILD          #   welcome window, store launcher, updater
│   └── lin-defaults/PKGBUILD         #   Hyprland/waybar/wofi/kitty configs
├── scripts/build-lin-packages.sh     # builds the three local packages in CI
└── docs/
    ├── ARCHITECTURE.md
    ├── BUILD.md
    └── CUSTOMIZE.md
```

---

## How the build works

1. **You push to `main`** (or trigger via the Actions UI).
2. The `build-iso.yml` workflow runs inside an `archlinux:latest` container.
3. The container:
   - Installs `archiso`, `makepkg`, and other build deps.
   - Runs `scripts/build-lin-packages.sh` to build the three local packages
     (`lin-branding`, `lin-welcome`, `lin-defaults`) into `/repo/x86_64/`.
   - Adds `chaotic-aur` and the local `lin-local` repo to `pacman.conf`.
   - Sanity-checks that every package in `packages.x86_64` is installable.
   - Runs `mkarchiso -v -w work/ -o out/ .` to build the ISO.
   - Computes SHA256 + MD5 checksums.
4. The ISO is uploaded as a GitHub Actions artifact (14-day retention).
5. On git tags (`v*`), a GitHub Release is created with the ISO attached.

Build time: **~30–60 minutes** on GitHub Actions free tier (2 CPU, 7 GB RAM).

---

## Building locally

You can build the ISO locally in Docker (no Arch install required):

```bash
git clone https://github.com/salom600/lin.git
cd lin

docker run --rm -it --privileged \
  -v "$PWD:/build" \
  -w /build \
  archlinux:latest \
  bash -c '
    pacman -Syu --noconfirm archiso git base-devel sudo wget curl
    pacman-key --init && pacman-key --populate archlinux
    useradd -m -G wheel buildbot
    echo "buildbot ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/buildbot
    chmod 0440 /etc/sudoers.d/buildbot
    mkdir -p /repo/x86_64 /work /out
    SRC_ROOT=/build OUTPUT_DIR=/output sudo -u buildbot bash scripts/build-lin-packages.sh
    mkarchiso -v -w /work -o /out .
    ls -lh /out/
  '
```

See [docs/BUILD.md](docs/BUILD.md) for the full local-build guide.

---

## Installing Lin OS

1. Download the latest ISO from [Releases](https://github.com/salom600/lin/releases).
2. Flash it to a USB stick:
   ```bash
   sudo dd if=lin-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```
   Or use [Rufus](https://rufus.ie/) / [balenaEtcher](https://etcher.balena.io/) on Windows.
3. Boot from the USB. The live ISO auto-logs into Hyprland.
4. Click "Install Lin OS" on the desktop (or run `sudo calamares`).
5. Calamares walks you through:
   - **Language** pick
   - **Disk** pick (with autopartition — "Erase disk" for one-click install)
   - **User** pick (username, hostname, password)
   - **Install** → unpackfs copies the live system onto the disk
6. Reboot. The first-boot wizard refreshes mirrors and sets up the AUR keyring.

---

## Using Lin OS — quick reference for Windows migrants

| Action | Windows 11 | Lin OS |
|---|---|---|
| Open app launcher | `Win` key | `Super` (Win) key, or click ❖ on the dock |
| Open File Explorer | `Win + E` | `Super + E` |
| Open Terminal | `Win + X, T` | `Super + Enter` |
| Open browser | (varies) | `Super + B` |
| Close window | `Alt + F4` | `Super + Q` |
| Switch workspace | `Ctrl + Win + ←/→` | `Super + Ctrl + ←/→` |
| Move window to workspace | `Win + Shift + ←/→` | `Super + Shift + 1..9` |
| Take screenshot | `Win + Shift + S` | `Super + Shift + S` |
| Lock screen | `Win + L` | `Super + L` |
| Open app store | (varies) | `Super + S` |

---

## Performance targets

| Metric | Target | How |
|---|---|---|
| Idle RAM | ~150 MB | Hyprland + waybar + minimal daemons. No Electron apps at startup. |
| Idle CPU | 0% | TLP powersave governor, hypridle dim/off/suspend cascade, no polling daemons. |
| Cold boot time | < 15 s | SquashFS + zstd compression, quiet kernel cmdline, no splash. |
| Install time | < 8 min | unpackfs copies the in-RAM airootfs directly to disk. |
| ISO size | ~1.5–2 GB | SquashFS + zstd-19 compression. |

---

## Customizing

See [docs/CUSTOMIZE.md](docs/CUSTOMIZE.md) for:
- Adding/removing packages from the ISO
- Changing the wallpaper / theme
- Changing the default keybinds
- Adding your own apps to the app launcher
- Building your own branded ISO

---

## Contributing

Pull requests welcome. Please:
1. Open an issue first to discuss what you want to change.
2. Test your change locally before opening a PR.
3. Keep the package list lean — every extra package adds to the ISO size.

---

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).

The Lin OS artwork (wallpapers, icons, themes) is dual-licensed GPL-3.0 + CC-BY-4.0.

---

## Acknowledgements

Lin OS is built on the shoulders of giants:

- [Arch Linux](https://archlinux.org/) — the base distribution
- [archiso](https://gitlab.archlinux.org/archlinux/archiso) — ISO build tool
- [Hyprland](https://hyprland.org/) — the Wayland compositor
- [waybar](https://github.com/Alexays/Waybar) — the status bar
- [wofi](https://hg.sr.ht/~scoopta/wofi) — the app launcher
- [Calamares](https://calamares.io/) — the installer
- [Bauh](https://github.com/vinifmor/bauh) — the app store
- [chaotic-aur](https://aur.chaotic.cx/) — prebuilt AUR packages
