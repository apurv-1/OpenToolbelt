#!/usr/bin/env bash
# Builds dist/OpenToolbelt.app for Apple Silicon. Pass --dmg to also build dist/OpenToolbelt.dmg.
# The app is ad-hoc signed, not notarized: on first launch, macOS asks you to
# allow it in System Settings > Privacy & Security.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
APP="dist/OpenToolbelt.app"

swift build -c release --arch arm64 --product OpenToolbeltApp
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/OpenToolbeltApp" "$APP/Contents/MacOS/OpenToolbelt"
# SwiftPM resources (agent icons); Bundle.module finds them in Contents/Resources.
cp -R "$BIN_DIR/OpenToolbelt_OpenToolbeltApp.bundle" "$APP/Contents/Resources/"

ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" Design/AppIcon/AppIcon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) Design/AppIcon/AppIcon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>OpenToolbelt</string>
  <key>CFBundleDisplayName</key><string>OpenToolbelt</string>
  <key>CFBundleIdentifier</key><string>dev.opentoolbelt.app</string>
  <key>CFBundleExecutable</key><string>OpenToolbelt</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--dmg" ]]; then
  STAGE="$(mktemp -d)"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname OpenToolbelt -srcfolder "$STAGE" -ov -format UDZO dist/OpenToolbelt.dmg >/dev/null
  echo "Built dist/OpenToolbelt.dmg"
fi
