#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/build/Build/Products/Release/SenovativeWrite.app"
DMG_PATH="$ROOT_DIR/SenovativeWrite.dmg"

echo "Building Senovative Write (Release)..."
"$ROOT_DIR/Tools/build.sh"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App bundle not found at $APP_PATH"
    exit 1
fi

echo "Creating DMG..."
rm -f "$DMG_PATH"

STAGING_DIR="$(mktemp -d)"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

if command -v create-dmg > /dev/null; then
    create-dmg \
      --volname "Senovative Write" \
      --window-pos 200 120 \
      --window-size 600 400 \
      --icon-size 100 \
      --icon "SenovativeWrite.app" 150 150 \
      --hide-extension "SenovativeWrite.app" \
      --app-drop-link 450 150 \
      "$DMG_PATH" \
      "$STAGING_DIR" || {
        echo "create-dmg failed, falling back to hdiutil..."
        hdiutil create -volname "Senovative Write" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"
      }
else
    hdiutil create -volname "Senovative Write" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"
fi

rm -rf "$STAGING_DIR"
echo "Successfully created $DMG_PATH"
