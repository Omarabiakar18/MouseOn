#!/usr/bin/env bash
# Build a styled DMG for MouseOn
#
# Usage: ./scripts/build-dmg.sh [version]
#   version  — semver string, defaults to "dev"
#
# Prerequisites:
#   brew install create-dmg

set -euo pipefail

APP_NAME="MouseOn"
SCHEME="MouseOn"
PROJECT="MouseOn.xcodeproj"
VERSION="${1:-dev}"
DMG_NAME="${APP_NAME}-${VERSION}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build"
EXPORT_DIR="$BUILD_DIR/Export"
DIST_DIR="$REPO_ROOT/dist"
BG_IMAGE="$REPO_ROOT/dmg-resources/background@2x.png"

echo "==> Building $APP_NAME $VERSION"

# ── 1. Archive ──────────────────────────────────────────────
echo "==> Archiving..."
xcodebuild archive \
  -project "$REPO_ROOT/$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=NO \
  -quiet

# ── 2. Export app from archive ──────────────────────────────
echo "==> Exporting app..."
rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"
cp -R "$BUILD_DIR/$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app" "$EXPORT_DIR/"

# ── 3. Create DMG ──────────────────────────────────────────
mkdir -p "$DIST_DIR"
DMG_PATH="$DIST_DIR/${DMG_NAME}.dmg"
rm -f "$DMG_PATH"

if command -v create-dmg &>/dev/null; then
  echo "==> Creating styled DMG with create-dmg..."

  # Create a Finder alias (not symlink) to /Applications so the folder icon renders
  rm -f "$EXPORT_DIR"/Applications*
  osascript -e "tell application \"Finder\"
    set a to make alias file to POSIX file \"/Applications\" at POSIX file \"$EXPORT_DIR\"
    set name of a to \"Applications\"
  end tell" || ln -sfn /Applications "$EXPORT_DIR/Applications"

  CREATE_DMG_ARGS=(
    --volname "$APP_NAME"
    --window-pos 200 120
    --window-size 660 400
    --icon-size 128
    --icon "$APP_NAME.app" 150 190
    --hide-extension "$APP_NAME.app"
    --icon "Applications" 510 190
  )

  if [ -f "$BG_IMAGE" ]; then
    CREATE_DMG_ARGS+=(--background "$BG_IMAGE")
  fi

  create-dmg "${CREATE_DMG_ARGS[@]}" "$DMG_PATH" "$EXPORT_DIR/" || true

  if [ ! -f "$DMG_PATH" ]; then
    echo "Warning: create-dmg failed, falling back to hdiutil"
  fi
fi

# Fallback if create-dmg is missing or failed
if [ ! -f "$DMG_PATH" ]; then
  echo "==> Creating DMG with hdiutil (no styling)..."
  hdiutil create -volname "$APP_NAME" \
    -srcfolder "$EXPORT_DIR/" \
    -ov -format UDZO \
    "$DMG_PATH"
fi

echo ""
echo "==> Done! DMG at: $DMG_PATH"
ls -lh "$DMG_PATH"
