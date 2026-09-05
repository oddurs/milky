#!/bin/bash
# Builds a distributable Milky.dmg: release build, Developer ID signature,
# hardened runtime, notarization, stapled ticket.
#
#   CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)" \
#   NOTARY_PROFILE=milky Scripts/release.sh
#
# Create the notary profile once with:
#   xcrun notarytool store-credentials milky \
#     --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
#
# Without CODESIGN_IDENTITY this still produces a DMG, but an ad-hoc-signed one
# that Gatekeeper will refuse on any other Mac. Use --allow-unsigned to say you
# meant that; otherwise the script stops rather than handing you a dud.
set -euo pipefail
cd "$(dirname "$0")/.."
source Scripts/version.sh

ALLOW_UNSIGNED=0
for arg in "$@"; do
  [ "$arg" = "--allow-unsigned" ] && ALLOW_UNSIGNED=1
done

OUT="release"
APP="build/Milky.app"
DMG="$OUT/Milky-$VERSION.dmg"
STAGE="$(mktemp -d)/Milky"

if [ -z "${CODESIGN_IDENTITY:-}" ] && [ "$ALLOW_UNSIGNED" -eq 0 ]; then
  cat >&2 <<'MSG'
No CODESIGN_IDENTITY set.

Milky would be signed ad-hoc, which Gatekeeper blocks on every Mac except this
one — so the DMG would be unusable as a download. Set a Developer ID identity:

    security find-identity -v -p codesigning     # list what you have
    export CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)"

Or pass --allow-unsigned to build a local-only disk image anyway.
MSG
  exit 1
fi

# 1. Build and sign the app.
Scripts/bundle.sh release

# 2. Notarize. Apple needs a container, and a zip is faster to upload than a DMG.
if [ -n "${NOTARY_PROFILE:-}" ]; then
  ZIP="$(mktemp -d)/Milky.zip"
  ditto -c -k --keepParent "$APP" "$ZIP"

  echo "Submitting to Apple for notarization (this usually takes a few minutes)…"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

  # Stapling lets the app launch offline; without it Gatekeeper must phone home.
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
elif [ "$ALLOW_UNSIGNED" -eq 0 ]; then
  echo "NOTARY_PROFILE not set — skipping notarization." >&2
  echo "Gatekeeper will still warn on first launch. See the header of this script." >&2
fi

# 3. Lay out the disk image: the app, and somewhere to drag it.
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Milky.app"
ln -s /Applications "$STAGE/Applications"

mkdir -p "$OUT"
rm -f "$DMG"
hdiutil create -volname "Milky $VERSION" -srcfolder "$STAGE" \
               -ov -format UDZO "$DMG" >/dev/null
rm -rf "$(dirname "$STAGE")"

# 4. Sign the image itself, so the download is verifiable before it is opened.
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  codesign --force --sign "$CODESIGN_IDENTITY" "$DMG"
  [ -n "${NOTARY_PROFILE:-}" ] && xcrun stapler staple "$DMG"
fi

echo
echo "$DMG  —  $(du -h "$DMG" | cut -f1)"
echo
echo "Verify the way a downloader's Mac will:"
echo "  spctl --assess --type execute --verbose $APP"
echo "  codesign --verify --deep --strict --verbose=2 $APP"
