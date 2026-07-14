#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
./scripts/generate_xcodeproj.sh

run_xcodebuild() {
  # Xcode 26's SwiftBuild service can block when its external-tool stdout is
  # attached to a pipe. A PTY keeps the build deterministic in CI and shells.
  if command -v script >/dev/null 2>&1; then
    script -q /dev/null xcodebuild "$@" | perl -pe 's/\r//g; s/\x04\x08\x08//g'
    local status="${PIPESTATUS[0]}"
    return "$status"
  else
    xcodebuild "$@"
  fi
}

run_xcodebuild \
  -project MyMonitor.xcodeproj \
  -scheme MyMonitor \
  -configuration "${1:-Debug}" \
  -sdk macosx \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
