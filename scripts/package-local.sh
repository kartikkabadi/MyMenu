#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="MyMenu"
PROJECT="$ROOT/MyMenu.xcodeproj"
CONFIG="${1:-Release}"
DERIVED="$ROOT/build/DerivedData"
DIST="$ROOT/dist"
ENTITLEMENTS="$ROOT/MyMenu/MyMenu.entitlements"
SIGN_ID="${SIGN_ID:--}"

cd "$ROOT"

if ! xcodebuild -version &>/dev/null; then
  echo "error: xcodebuild requires full Xcode (sudo xcode-select -s /Applications/Xcode.app/Contents/Developer)" >&2
  exit 1
fi

echo "==> Building $SCHEME ($CONFIG)..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  build

APP="$DERIVED/Build/Products/$CONFIG/${SCHEME}.app"
if [[ ! -d "$APP" ]]; then
  echo "error: missing $APP" >&2
  exit 1
fi

echo "==> Signing..."
if [[ -f "$ENTITLEMENTS" ]]; then
  codesign --force --sign "$SIGN_ID" --entitlements "$ENTITLEMENTS" "$APP"
else
  codesign --force --sign "$SIGN_ID" "$APP"
fi
codesign --verify --deep --strict --verbose=2 "$APP"
xattr -cr "$APP" 2>/dev/null || true

mkdir -p "$DIST"
rm -f "$DIST/${SCHEME}.zip"
ditto -c -k --keepParent "$APP" "$DIST/${SCHEME}.zip"
echo "ZIP: $DIST/${SCHEME}.zip"

STAGE="$DIST/stage"
rm -rf "$STAGE" "$DIST/${SCHEME}.dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"

if command -v create-dmg &>/dev/null; then
  create-dmg \
    --volname "$SCHEME" \
    --window-pos 200 120 --window-size 600 320 \
    --icon-size 80 \
    --icon "${SCHEME}.app" 120 160 \
    --hide-extension "${SCHEME}.app" \
    --app-drop-link 400 160 \
    --skip-jenkins \
    "$DIST/${SCHEME}.dmg" \
    "$STAGE" 2>/dev/null || true
fi

if [[ ! -f "$DIST/${SCHEME}.dmg" ]]; then
  hdiutil create -volname "$SCHEME" -srcfolder "$STAGE" -ov -format UDZO "$DIST/${SCHEME}.dmg"
fi
echo "DMG: $DIST/${SCHEME}.dmg"

echo ""
echo "Install: cp -R \"$APP\" /Applications/ && open /Applications/${SCHEME}.app"
echo "If blocked: xattr -dr com.apple.quarantine /Applications/${SCHEME}.app"
