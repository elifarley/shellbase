#!/bin/sh
# kitty-desktop-setup.sh -- Kitty Desktop Integration for Pop!_OS/COSMIC
#
# PROBLEM:
#   Kitty terminal installed locally in ~/.local/kitty.app/ does not appear in
#   the Pop!_OS app launcher because the desktop entry and icons are not in
#   the standard XDG locations where the desktop environment looks for apps.
#
# ROOT CAUSE:
#   - Desktop entry: ~/.local/kitty.app/share/applications/kitty.desktop
#   - Icons: ~/.local/kitty.app/share/icons/hicolor/*/{apps/kitty.png,apps/kitty.svg}
#   These exist in the kitty.app bundle but are not discoverable by the
#   COSMIC app launcher, which only looks in:
#   - ~/.local/share/applications/ for desktop entries
#   - ~/.local/share/icons/ for icons
#
# SOLUTION:
#   1. Copy the desktop entry and modify Exec/TryExec to use absolute paths
#   2. Symlink kitty icons into the existing hicolor icon theme directory
#   3. Update the desktop database to refresh the app launcher cache
#
# IDEMPOTENT: Safe to run multiple times (symlinks use -sf, copy uses -f)
#
# Author: Claude Code
# Version: 1.0

set -e  # Exit on error

# ============================================================================
# Configuration
# ============================================================================

KITTY_APP="${HOME}/.local/kitty.app"
KITTY_BIN="${KITTY_APP}/bin/kitty"
KITTY_DESKTOP_SRC="${KITTY_APP}/share/applications/kitty.desktop"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICONS_DIR="${HOME}/.local/share/icons"

# ============================================================================
# Prerequisites Check
# ============================================================================

if [ ! -d "${KITTY_APP}" ]; then
    echo "Error: Kitty app bundle not found at ${KITTY_APP}"
    echo "Please install kitty locally first."
    exit 1
fi

if [ ! -f "${KITTY_DESKTOP_SRC}" ]; then
    echo "Error: Kitty desktop entry not found at ${KITTY_DESKTOP_SRC}"
    exit 1
fi

# ============================================================================
# 1. Create Desktop Entry with Absolute Paths
# ============================================================================

echo "[1/3] Installing desktop entry..."

# Ensure target directory exists
mkdir -p "${DESKTOP_DIR}"

# Copy desktop entry and modify Exec/TryExec to use absolute paths
# We use sed to rewrite the paths in-place after copying
sed "s|^TryExec=kitty|TryExec=${KITTY_BIN}|; s|^Exec=kitty|Exec=${KITTY_BIN}|" \
    "${KITTY_DESKTOP_SRC}" > "${DESKTOP_DIR}/kitty.desktop"

echo "  Installed: ${DESKTOP_DIR}/kitty.desktop"

# ============================================================================
# 2. Symlink Icons into Existing hicolor Theme
# ============================================================================

echo "[2/3] Installing icons..."

# Kitty provides icons in two sizes under share/icons/hicolor/:
#   - 256x256/apps/kitty.png
#   - scalable/apps/kitty.svg
#
# Since ~/.local/share/icons/hicolor/ already exists (from other apps),
# we symlink each icon directory individually rather than symlinking the
# entire hicolor parent (which would cause conflicts).

# Create target directories for each size
mkdir -p "${ICONS_DIR}/hicolor/256x256/apps"
mkdir -p "${ICONS_DIR}/hicolor/scalable/apps"

# Symlink the PNG icon
ln -sf "${KITTY_APP}/share/icons/hicolor/256x256/apps/kitty.png" \
       "${ICONS_DIR}/hicolor/256x256/apps/kitty.png"

# Symlink the SVG icon
ln -sf "${KITTY_APP}/share/icons/hicolor/scalable/apps/kitty.svg" \
       "${ICONS_DIR}/hicolor/scalable/apps/kitty.svg"

echo "  Installed icons:"
echo "    ${ICONS_DIR}/hicolor/256x256/apps/kitty.png"
echo "    ${ICONS_DIR}/hicolor/scalable/apps/kitty.svg"

# ============================================================================
# 3. Update Desktop Database
# ============================================================================

echo "[3/3] Updating desktop database..."

# Rebuild the desktop entry cache so the app launcher immediately discovers kitty
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${DESKTOP_DIR}"
    echo "  Desktop database updated."
else
    echo "  Warning: update-desktop-database not found, skipping cache update."
    echo "  You may need to log out and back in for kitty to appear in the launcher."
fi

# ============================================================================
# Done
# ============================================================================

echo ""
echo "Kitty desktop integration complete!"
echo ""
echo "Next steps:"
echo "  1. Open the app launcher (Super key)"
echo "  2. Search for 'kitty' - it should now appear"
echo "  3. Click to launch, or right-click to add to dock"
echo ""
echo "Note: If kitty doesn't appear immediately, try:"
echo "  - Pressing Super + Escape to refresh COSMIC (Pop!_OS)"
echo "  - Logging out and back in"
echo "  - Running: killall cos-panel && cos-panel &"
