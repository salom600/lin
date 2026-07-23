#!/usr/bin/env bash
# =============================================================================
# build-lin-packages.sh — builds the three local Lin OS packages
# =============================================================================
# This script runs INSIDE the Arch Linux build container (GitHub Actions).
# It builds:
#   1. lin-branding   — wallpapers, GTK theme, SDDM theme, icons
#   2. lin-welcome    — welcome window, store launcher, update helper
#   3. lin-defaults   — Hyprland/waybar/wofi/kitty configs (copied from
#                       airootfs/etc/skel so the package and the live ISO
#                       are guaranteed to have the same files)
#
# Output: a local repo at /repo/x86_64/*.pkg.tar.zst that pacman.conf's
# [lin-local] section points at. archiso will pick these up automatically
# during the airootfs bootstrap.
# =============================================================================
set -euo pipefail

REPO_DIR="/repo"
PKG_DIR="${REPO_DIR}/x86_64"
SRC_ROOT="${SRC_ROOT:-/build}"   # path to the cloned repo
OUTPUT_DIR="${OUTPUT_DIR:-/output}"

mkdir -p "${PKG_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Initialize the local repo database
repo-add "${PKG_DIR}/lin-local.db.tar" 2>/dev/null || true

# -----------------------------------------------------------------------------
# Helper: build a single package and add it to the local repo
# -----------------------------------------------------------------------------
build_pkg() {
    local pkgname="$1"
    local pkgsrc="$2"
    local workdir
    workdir="$(mktemp -d)"
    echo "==> [lin] building ${pkgname} in ${workdir}"

    cp -a "${pkgsrc}" "${workdir}/"
    cd "${workdir}/${pkgname}"

    # For lin-defaults: copy airootfs/etc/skel into the PKGBUILD's startdir
    # (NOT into src/, because `makepkg -f` wipes src/ before building).
    # The PKGBUILD references this as ${startdir}/skel in package().
    if [ "${pkgname}" = "lin-defaults" ]; then
        rm -rf skel
        cp -aT "${SRC_ROOT}/airootfs/etc/skel" "skel"
    fi

    # makepkg refuses to run as root. The CI workflow already invokes this
    # script as user 'buildbot' (non-root), so we can call makepkg directly.
    # (No chown / sudo -u dance needed — that pattern only applies when the
    #  script itself runs as root and needs to drop privileges.)
    #
    # Temporarily disable `set -e` around the pipeline so we can capture
    # makepkg's exit code via PIPESTATUS (tee always succeeds, so without
    # this we'd lose makepkg's failure code under pipefail).
    set +e
    makepkg -sf --noconfirm --skippgpcheck \
        2>&1 | tee "${OUTPUT_DIR}/${pkgname}-build.log"
    local makepkg_rc="${PIPESTATUS[0]}"
    set -e

    if [ "${makepkg_rc}" -ne 0 ]; then
        echo "ERROR: makepkg failed for ${pkgname} (exit ${makepkg_rc})" >&2
        echo "       See ${OUTPUT_DIR}/${pkgname}-build.log for full output." >&2
        exit 1
    fi

    # Find the built package (glob-safe: if no match, the loop body doesn't run)
    local built=""
    local f
    for f in "${pkgname}"-*.pkg.tar.zst; do
        [ -f "$f" ] || continue
        built="$f"
        break
    done
    if [ -z "${built}" ]; then
        echo "ERROR: ${pkgname} build produced no .pkg.tar.zst" >&2
        exit 1
    fi
    cp "${built}" "${PKG_DIR}/"
    repo-add "${PKG_DIR}/lin-local.db.tar" "${PKG_DIR}/${built}"

    cd - >/dev/null
    rm -rf "${workdir}"
    echo "==> [lin] ${pkgname} added to local repo"
}

# -----------------------------------------------------------------------------
# Build all three packages
# -----------------------------------------------------------------------------
build_pkg lin-branding "${SRC_ROOT}/packages/lin-branding"
build_pkg lin-welcome  "${SRC_ROOT}/packages/lin-welcome"
build_pkg lin-defaults "${SRC_ROOT}/packages/lin-defaults"

# -----------------------------------------------------------------------------
# Verify
# -----------------------------------------------------------------------------
echo "==> [lin] local repo contents:"
ls -la "${PKG_DIR}/"

echo "==> [lin] building local packages complete"
