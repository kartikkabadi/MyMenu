#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="MyMonitor"
PROJECT="$ROOT/MyMonitor.xcodeproj"
CONFIG="${1:-Release}"
DERIVED="$ROOT/build/DerivedData"
DIST="$ROOT/dist"
ENTITLEMENTS="$ROOT/MyMonitor/MyMonitor.entitlements"
SIGN_ID="${SIGN_ID:--}"

cd "$ROOT"
./scripts/generate_xcodeproj.sh >/dev/null

if ! xcodebuild -version &>/dev/null; then
  echo "error: xcodebuild requires full Xcode" >&2
  exit 1
fi

echo "==> Building $SCHEME ($CONFIG)..."
run_xcodebuild() {
  # Xcode 26's SwiftBuild service can block when its external-tool stdout is
  # attached to a pipe. A PTY keeps packaging deterministic in shells.
  if command -v script >/dev/null 2>&1; then
    script -q /dev/null xcodebuild "$@" | perl -pe 's/\r//g; s/\x04\x08\x08//g'
    local status="${PIPESTATUS[0]}"
    return "$status"
  else
    xcodebuild "$@"
  fi
}

run_xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -sdk macosx \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED" \
  -jobs 1 \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

APP="$DERIVED/Build/Products/$CONFIG/${SCHEME}.app"
if [[ ! -d "$APP" ]]; then
  echo "error: missing $APP" >&2
  exit 1
fi

echo "==> Signing ad hoc release artifact..."
codesign --force --sign "$SIGN_ID" --entitlements "$ENTITLEMENTS" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
xattr -cr "$APP" 2>/dev/null || true

mkdir -p "$DIST"
STAGE="$DIST/MyMonitor-Installer"
rm -rf "$STAGE" "$DIST/MyMonitor.zip" "$DIST/MyMonitor.dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/MyMonitor.app"
cp "$ROOT/installer/Install MyMonitor.command" "$STAGE/Install MyMonitor.command"
cp "$ROOT/installer/README.txt" "$STAGE/README.txt"
chmod +x "$STAGE/Install MyMonitor.command"

ditto -c -k --keepParent "$STAGE" "$DIST/MyMonitor.zip"

if command -v create-dmg &>/dev/null; then
  create-dmg \
    --volname "MyMonitor" \
    --window-pos 200 120 --window-size 600 360 \
    --icon-size 80 \
    --icon "MyMonitor.app" 120 160 \
    --icon "Install MyMonitor.command" 400 160 \
    --hide-extension "MyMonitor.app" \
    --skip-jenkins \
    "$DIST/MyMonitor.dmg" \
    "$STAGE" 2>/dev/null || true
fi

if [[ ! -f "$DIST/MyMonitor.dmg" ]]; then
  hdiutil create -volname "MyMonitor" -srcfolder "$STAGE" -ov -format UDZO "$DIST/MyMonitor.dmg" >/dev/null
fi

echo "ZIP: $DIST/MyMonitor.zip"
echo "DMG: $DIST/MyMonitor.dmg"
echo "The included installer removes the quarantine flag and opens the app; it does not change privacy permissions."
