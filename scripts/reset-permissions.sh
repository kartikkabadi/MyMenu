#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="com.mymonitor.MyMonitor"

echo "Resetting MyMonitor preferences and macOS privacy entries..."
defaults delete "$BUNDLE_ID" 2>/dev/null || true
tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true
tccutil reset ScreenCapture "$BUNDLE_ID" 2>/dev/null || true
echo "Done. Launch MyMonitor again for a fresh onboarding and permission flow."
