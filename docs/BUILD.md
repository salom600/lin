# Build guide

This document covers all the ways to build Lin OS.

## Option A — Let GitHub Actions build it (recommended)

Just push to `main`. The Actions workflow builds the ISO automatically and
uploads it as an artifact you can download.

1. Go to https://github.com/salom600/lin/actions
2. Click the latest "Build Lin OS ISO" run
3. Scroll to "Artifacts" at the bottom
4. Download `lin-os-iso-<run-id>` (1.5–2 GB)

To create a Release (with the ISO attached), push a tag:

```bash
git tag v2026.07.1
git push origin v2026.07.1
```

The workflow will create a GitHub Release and attach the ISO + checksums.

## Option B — Build locally with Docker

You don't need Arch installed — Docker can run the archlinux container for you.

```bash
git clone https://github.com/salom600/lin.git
cd lin

docker run --rm -it --privileged \
  -v "$PWD:/build" \
  -w /build \
  archlinux:latest \
  bash -c '
    set -e

    # Initialize
    pacman -Syu --noconfirm archiso git base-devel sudo wget curl reflector \
      imagemagick librsvg qt5-svg inkscape python python-pillow pyalpm
    pacman-key --init && pacman-key --populate archlinux

    # Create build user (makepkg refuses to run as root)
    useradd -m -G wheel buildbot
    echo "buildbot ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/buildbot
    chmod 0440 /etc/sudoers.d/buildbot

    # Set up directories
    mkdir -p /repo/x86_64 /work /out /output
    chown -R buildbot:buildbot /repo /out /output /build

    # Add chaotic-aur
    cat >> /etc/pacman.conf <<EOF

[chaotic-aur]
Server = https://cdn-mirror.chaotic.cx/\$repo/\$arch
EOF
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB
    pacman -Sy

    # Build local packages
    SRC_ROOT=/build OUTPUT_DIR=/output \
      sudo -u buildbot bash scripts/build-lin-packages.sh

    # Add lin-local to pacman.conf
    cat >> /etc/pacman.conf <<EOF

[lin-local]
Server = file:///repo/\$arch
SigLevel = Optional TrustAll
EOF
    pacman -Sy

    # Build the ISO
    mkarchiso -v -w /work -o /out .
    ls -lh /out/
  '
```

The ISO will be in `./out/` after the build completes.

## Option C — Build on a real Arch install

If you already run Arch, you can build natively (faster than Docker):

```bash
sudo pacman -S archiso git base-devel sudo wget curl reflector \
  imagemagick librsvg qt5-svg inkscape python python-pillow pyalpm

git clone https://github.com/salom600/lin.git
cd lin

# Build local packages
mkdir -p /tmp/lin-repo/x86_64
cd packages/lin-branding && makepkg -sf --noconfirm && \
  cp lin-branding-*.pkg.tar.zst /tmp/lin-repo/x86_64/ && \
  repo-add /tmp/lin-repo/x86_64/lin-local.db.tar \
    /tmp/lin-repo/x86_64/lin-branding-*.pkg.tar.zst
cd - && cd packages/lin-welcome && makepkg -sf --noconfirm && \
  cp lin-welcome-*.pkg.tar.zst /tmp/lin-repo/x86_64/ && \
  repo-add /tmp/lin-repo/x86_64/lin-local.db.tar \
    /tmp/lin-repo/x86_64/lin-welcome-*.pkg.tar.zst
cd - && cd packages/lin-defaults
mkdir -p src/skel && cp -aT ../../airootfs/etc/skel src/skel
makepkg -sf --noconfirm
cp lin-defaults-*.pkg.tar.zst /tmp/lin-repo/x86_64/
repo-add /tmp/lin-repo/x86_64/lin-local.db.tar \
  /tmp/lin-repo/x86_64/lin-defaults-*.pkg.tar.zst
cd ../..

# Add local repo to a temp pacman.conf
cp pacman.conf /tmp/lin-pacman.conf
sed -i 's|Server = file:///repo/$arch|Server = file:///tmp/lin-repo/$arch|' \
  /tmp/lin-pacman.conf

# Build the ISO
sudo mkarchiso -v -w work -o out -c /tmp/lin-pacman.conf .
ls -lh out/
```

## Build times

| Method | Time | Disk usage |
|---|---|---|
| GitHub Actions | 30–60 min | ~10 GB |
| Docker on modern laptop | 20–40 min | ~10 GB |
| Native Arch | 15–25 min | ~8 GB |

## Verifying the ISO

```bash
sha256sum -c sha256sum.txt
```

The output should say `lin-*.iso: OK`.

## Flashing the ISO

### On Linux / macOS
```bash
sudo dd if=lin-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

### On Windows
Use [Rufus](https://rufus.ie/) or [balenaEtcher](https://etcher.balena.io/).
Choose "DD mode" if Rufus asks.

## Booting

1. Plug the USB into the target machine.
2. Boot from USB (press F12 / F2 / F8 / Esc — varies by vendor).
3. Pick "Lin OS (x86_64, UEFI)" from the menu.
4. The live ISO auto-logs into Hyprland as user `lin` / password `lin`.
5. Click "Install Lin OS" on the desktop, or run `sudo calamares`.

## Troubleshooting

### "Package not found" errors
- Make sure chaotic-aur is properly added to pacman.conf.
- The build script adds it automatically — check `/output/archiso-build.log`.

### "ISO too big" / out-of-disk
- Remove some packages from `packages.x86_64`.
- The biggest contributors are: `noto-fonts-cjk` (~500 MB), `firefox` (~250 MB),
  `kitty` (~200 MB), `linux-firmware` (~400 MB).

### mkarchiso fails with permission errors
- Make sure you're running as root (or with sudo) for the `mkarchiso` step.
- The local package builds run as a non-root user (`buildbot`) because makepkg
  refuses to run as root.
