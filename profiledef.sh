#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# Lin OS — archiso profile definition
#
# This file is sourced by mkarchiso. It declares metadata about the ISO
# (name, publisher, version, architecture) and the package set used to
# build the airootfs.
#
# Build with:
#   mkarchiso -v -w work/ -o out/ .
#

# ---- Identity ---------------------------------------------------------------
iso_name="lin"
iso_label="LIN_OS"
iso_publisher="Lin OS Project <https://github.com/salom600/lin>"
iso_application="Lin OS — Lightweight, sleek, user-friendly Linux"
iso_version="$(date --utc +%Y.%m.%d)"
install_dir="lin"
buildmodes=('iso')

# ---- Architecture -----------------------------------------------------------
arch="x86_64"
# pacman architectures this profile can build for
archisoinitrd_arch="x86_64"

# ---- Boot configuration -----------------------------------------------------
# These point at the bootloader config files shipped in this directory.
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')

# ---- Filesystem -------------------------------------------------------------
# SquashFS + zstd gives us the smallest live image with fast random access.
# zstd is much faster than xz at comparable compression ratios.
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M')

# ---- Misc -------------------------------------------------------------------
# File permissions to set on the airootfs after build (key system files).
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/customize_airootfs.sh"]="0:0:755"
  ["/etc/lin/firstboot.sh"]="0:0:755"
  ["/etc/lin/welcome.sh"]="0:0:755"
  ["/etc/lin/install-store.sh"]="0:0:755"
  ["/usr/local/bin/lin-welcome"]="0:0:755"
  ["/usr/local/bin/lin-store"]="0:0:755"
  ["/usr/local/bin/lin-update"]="0:0:755"
)
