#!/bin/bash
# Regenerates Resources/AppIcon.icns from Resources/port-manager-icon.png.
# Re-run this after replacing the source PNG with a new design.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="Resources/port-manager-icon.png"
ICONSET="$(mktemp -d)/AppIcon.iconset"

if [ ! -f "$SRC" ]; then
  echo "Missing $SRC — put the source icon PNG there first." >&2
  exit 1
fi

mkdir -p "$ICONSET"

sips -z 16 16     "$SRC" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64     "$SRC" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$SRC" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$SRC" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
rm -rf "$(dirname "$ICONSET")"

echo "Regenerated Resources/AppIcon.icns"
