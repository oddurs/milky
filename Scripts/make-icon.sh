#!/bin/bash
# Renders Resources/icon.html to a 1024px master with headless Chrome, then
# builds Milky.icns from it. Re-run after editing icon.html.
set -euo pipefail
cd "$(dirname "$0")/.."
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"

if [ -x "$CHROME" ]; then
  "$CHROME" --headless=new --disable-gpu --no-sandbox --hide-scrollbars \
    --default-background-color=00000000 --force-device-scale-factor=1 \
    --virtual-time-budget=1500 --window-size=1024,1024 \
    --screenshot="Resources/icon-1024.png" "file://$PWD/Resources/icon.html" 2>/dev/null
else
  echo "Chrome not found; reusing the committed Resources/icon-1024.png" >&2
fi

SET="$(mktemp -d)/Milky.iconset"
mkdir -p "$SET"
for spec in "16 16x16" "32 16x16@2x" "32 32x32" "64 32x32@2x" \
            "128 128x128" "256 128x128@2x" "256 256x256" "512 256x256@2x" \
            "512 512x512" "1024 512x512@2x"; do
  set -- $spec
  sips -z "$1" "$1" Resources/icon-1024.png --out "$SET/icon_$2.png" >/dev/null
done

iconutil -c icns "$SET" -o Resources/Milky.icns
rm -rf "$(dirname "$SET")"
echo "Resources/Milky.icns — $(du -h Resources/Milky.icns | cut -f1)"
