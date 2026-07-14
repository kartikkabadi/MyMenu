#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
./scripts/generate_xcodeproj.sh
xcodebuild \
  -project MyMonitor.xcodeproj \
  -scheme MyMonitor \
  -configuration "${1:-Debug}" \
  -sdk macosx \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
