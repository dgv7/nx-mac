#!/bin/bash
# build-splash.sh — compile NXSplash.swift into a universal .app bundle.
# Usage:
#   ./build-splash.sh                         # output to ./dist/NX Splash.app
#   ./build-splash.sh /path/to/output.app     # output to given path

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/NXSplash.swift"
OUT_APP="${1:-$SCRIPT_DIR/../../dist/NX Splash.app}"

command -v swiftc >/dev/null || { echo "[x] swiftc not found — install Xcode CLT"; exit 1; }
[ -f "$SRC" ] || { echo "[x] source not found: $SRC"; exit 1; }

echo "[*] Building universal binary"
rm -rf "$OUT_APP"
mkdir -p "$OUT_APP/Contents/MacOS" "$OUT_APP/Contents/Resources"

BIN="$OUT_APP/Contents/MacOS/NX Splash"
swiftc \
  -target arm64-apple-macos12.0 \
  -O \
  -o "/tmp/nxsplash-arm64.$$" \
  "$SRC"
swiftc \
  -target x86_64-apple-macos12.0 \
  -O \
  -o "/tmp/nxsplash-x86_64.$$" \
  "$SRC"
lipo -create "/tmp/nxsplash-arm64.$$" "/tmp/nxsplash-x86_64.$$" -output "$BIN"
rm -f "/tmp/nxsplash-arm64.$$" "/tmp/nxsplash-x86_64.$$"

echo "[*] Writing Info.plist"
cat > "$OUT_APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>NX Splash</string>
  <key>CFBundleDisplayName</key>
  <string>NX Launcher</string>
  <key>CFBundleIdentifier</key>
  <string>com.saeroon.nx-launcher.splash</string>
  <key>CFBundleVersion</key>
  <string>0.1</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1</string>
  <key>CFBundleExecutable</key>
  <string>NX Splash</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleSignature</key>
  <string>nxsp</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSSupportsAutomaticTermination</key>
  <false/>
  <key>NSSupportsSuddenTermination</key>
  <true/>
  <key>LSUIElement</key>
  <false/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

echo "[*] Codesigning (ad-hoc)"
codesign --force --deep --sign - "$OUT_APP"

echo "[*] Verifying"
codesign --verify --verbose=1 "$OUT_APP" 2>&1 | tail -3 || true
file "$BIN" | head -3
echo
echo "[✓] Built: $OUT_APP"
