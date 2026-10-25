#!/usr/bin/env bash
# Bouwt Island.app (universal: Apple Silicon + Intel) in ./build en zet een zip ernaast.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Island.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

if swift build -c release --arch arm64 --arch x86_64 2>/dev/null; then
  BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Island"
else
  echo "Universal build niet gelukt, bouw voor deze Mac alleen…"
  swift build -c release
  BIN="$(swift build -c release --show-bin-path)/Island"
fi

cp "$BIN" "$APP/Contents/MacOS/Island"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# App-icoon genereren (zwarte capsule op donkere achtergrond).
ICONSET="build/AppIcon.iconset"
mkdir -p "$ICONSET"
swift scripts/make-icon.swift "build/icon_1024.png"
for size in 16 32 128 256 512; do
  sips -z $size $size build/icon_1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size*2)) $((size*2)) build/icon_1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc ondertekenen zodat macOS de app (en de toestemmingen) herkent.
codesign --force --deep --sign - "$APP"

(cd build && ditto -c -k --keepParent Island.app Island.zip)
echo "Klaar: $APP"
