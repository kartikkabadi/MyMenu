#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$SOURCE_DIR/MyMonitor.app"

if [[ ! -d "$APP" ]]; then
  echo "MyMonitor.app is missing. Keep this installer next to the app and try again."
  read -r -p "Press Return to close..."
  exit 1
fi

if [[ -w /Applications ]]; then
  TARGET_DIR="/Applications"
else
  TARGET_DIR="$HOME/Applications"
  mkdir -p "$TARGET_DIR"
fi

TARGET="$TARGET_DIR/MyMonitor.app"
if [[ -d "$TARGET" ]]; then
  echo "Replacing the existing MyMonitor copy in $TARGET_DIR..."
  rm -rf "$TARGET"
fi

echo "Installing MyMonitor to $TARGET_DIR..."
ditto "$APP" "$TARGET"
xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true
echo "Installed. Launching MyMonitor..."
open "$TARGET"
read -r -p "Press Return to close..."
