#!/usr/bin/env bash
# =============================================================================
# build-calamares-from-aur.sh — builds calamares from AUR if not in repos
# =============================================================================
# Calamares is the system installer we use for Lin OS's "one-click install".
# In some Arch repo configurations, calamares is not in [extra] or [chaotic-aur]
# (availability varies over time). This script checks if it's available in any
# configured repo; if not, it clones the AUR package and builds it locally,
# adding the result to the lin-local repo so archiso can pick it up.
#
# This script runs as the non-root 'buildbot' user (makepkg refuses root).
# =============================================================================
set -euo pipefail

PKG_DIR="/repo/x86_64"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"

mkdir -p "${PKG_DIR}" "${OUTPUT_DIR}"

# -----------------------------------------------------------------------------
# 1. Check if calamares is already available in any repo
# -----------------------------------------------------------------------------
if pacman -Si calamares >/dev/null 2>&1; then
    echo "==> [lin] calamares IS available in repos — skipping AUR build."
    exit 0
fi

echo "==> [lin] calamares NOT found in any configured repo."
echo "==> [lin] Searching for calamares-related packages:"
pacman -Ss calamares || true

# -----------------------------------------------------------------------------
# 2. Clone the AUR package
# -----------------------------------------------------------------------------
echo "==> [lin] Building calamares from AUR"
workdir="$(mktemp -d)"
echo "==> [lin] workdir: ${workdir}"

# The AUR 'calamares' package is the stable release build.
# If git fails (network issue), try the git URL with https.
if ! git clone https://aur.archlinux.org/calamares.git "${workdir}/calamares"; then
    echo "ERROR: failed to clone calamares from AUR" >&2
    exit 1
fi

cd "${workdir}/calamares"

# Show the PKGBUILD for debugging
echo "==> [lin] PKGBUILD:"
head -30 PKGBUILD

# -----------------------------------------------------------------------------
# 3. Install build dependencies
# -----------------------------------------------------------------------------
# makepkg -s will install missing deps automatically via `sudo pacman -S --asdeps`.
# We need passwordless sudo for buildbot (already configured in the workflow).
# We also need the build deps that calamares requires:
#   cmake, extra-cmake-modules, boost, yaml-cpp, kpmcore, polkit-qt5-1,
#   qt5-svg, qt5-tools, kcrash, ckbcomp, hwinfo, appstream-qt, python-yaml
# Most of these are in [extra] and makepkg -s will pull them in.

# -----------------------------------------------------------------------------
# 4. Build (temporarily disable set -e to capture makepkg's exit code)
# -----------------------------------------------------------------------------
set +e
makepkg -sf --noconfirm --skippgpcheck --asdeps \
    2>&1 | tee "${OUTPUT_DIR}/calamares-build.log"
makepkg_rc="${PIPESTATUS[0]}"
set -e

if [ "${makepkg_rc}" -ne 0 ]; then
    echo "ERROR: makepkg failed for calamares (exit ${makepkg_rc})" >&2
    echo "       See ${OUTPUT_DIR}/calamares-build.log for full output." >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# 5. Copy to local repo
# -----------------------------------------------------------------------------
built=""
for f in calamares-*.pkg.tar.zst; do
    [ -f "$f" ] || continue
    built="$f"
    break
done

if [ -z "${built}" ]; then
    echo "ERROR: calamares build produced no .pkg.tar.zst" >&2
    exit 1
fi

echo "==> [lin] copying ${built} to local repo"
cp "${built}" "${PKG_DIR}/"
repo-add "${PKG_DIR}/lin-local.db.tar" "${PKG_DIR}/${built}"

cd - >/dev/null
rm -rf "${workdir}"

echo "==> [lin] calamares added to local repo"
echo "==> [lin] verifying:"
pacman -Si calamares || true
