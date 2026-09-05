#!/bin/bash
# Bundles the SPM-built executable into a runnable Milky.app.
#
# Signing: with no CODESIGN_IDENTITY the bundle is signed ad-hoc, which is fine
# for running locally. An ad-hoc signature has no stable identity, so macOS
# re-prompts for (and silently revokes) TCC access to protected folders like
# ~/Documents on every rebuild. Set CODESIGN_IDENTITY to a Developer ID for a
# build that keeps its permissions and can leave this machine.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"
source Scripts/version.sh          # VERSION, BUILD_NUMBER, BUNDLE_ID, MIN_MACOS

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/milky-mac"
APP="build/Milky.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Milky"

[ -f Resources/Milky.icns ] || Scripts/make-icon.sh >/dev/null
cp Resources/Milky.icns "$APP/Contents/Resources/Milky.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Milky</string>
  <key>CFBundleDisplayName</key><string>Milky</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>Milky</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
  <key>CFBundleIconFile</key><string>Milky</string>
  <key>CFBundleIconName</key><string>Milky</string>
  <key>LSMinimumSystemVersion</key><string>${MIN_MACOS}</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticTermination</key><true/>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Oddur Sigurdsson</string>
</dict></plist>
PLIST

if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  # Hardened runtime is required for notarization and cannot be added later.
  codesign --force --options runtime --timestamp \
           --sign "$CODESIGN_IDENTITY" "$APP"
  echo "Signed with: $CODESIGN_IDENTITY"
else
  codesign --force --sign - "$APP" 2>/dev/null || true
  echo "Signed ad-hoc (set CODESIGN_IDENTITY for a distributable build)"
fi

echo "Built $APP  —  $VERSION ($BUILD_NUMBER)"
