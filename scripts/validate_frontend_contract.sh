#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VIEWS="$ROOT/MyMonitor/Views"
APP="$ROOT/MyMonitor"

fail() {
  printf 'Frontend contract violation: %s\n' "$1" >&2
  exit 1
}

reject_pattern() {
  local pattern="$1"
  local path="$2"
  local explanation="$3"

  if grep -RInE --include='*.swift' "$pattern" "$path"; then
    fail "$explanation"
  fi
}

[[ -f "$ROOT/MyMonitor/Resources/Localizable.xcstrings" ]] \
  || fail "Localizable.xcstrings must remain bundled."
[[ -f "$ROOT/MyMonitor/Debug/FrontendPreviewGallery.swift" ]] \
  || fail "The deterministic frontend preview gallery is missing."

grep -q 'NSPopover' "$ROOT/MyMonitor/PopoverWindowController.swift" \
  || fail "The primary menu-bar surface must remain a native NSPopover."

reject_pattern 'NSPanel' "$APP" \
  "Do not replace the native popover or Settings window with NSPanel."
reject_pattern '\.glassEffect[[:space:]]*\(' "$APP" \
  "Do not apply custom Liquid Glass effects to ordinary app content."
reject_pattern '\.background[[:space:]]*\([[:space:]]*\.(regularMaterial|ultraThinMaterial|thinMaterial|thickMaterial)' "$VIEWS" \
  "The native popover/window owns material; do not nest material backgrounds in Views."
reject_pattern 'Color[[:space:]]*\([[:space:]]*(red:|#[0-9A-Fa-f]{3,8})' "$VIEWS" \
  "Use semantic system colors instead of fixed SwiftUI colors."
reject_pattern 'NSColor[[:space:]]*\([[:space:]]*(calibrated|device)' "$VIEWS" \
  "Use semantic AppKit colors instead of calibrated/device RGB colors."
reject_pattern '(LinearGradient|RadialGradient|AngularGradient)[[:space:]]*\(' "$VIEWS" \
  "Decorative gradients are outside the native frontend contract."
reject_pattern '(DisplayRouter|CGDirectDisplayID|BrightnessBackend|DDCBrightnessBackend|GammaBrightnessBackend|OverlayBrightnessBackend)' "$VIEWS" \
  "SwiftUI Views must consume presentation state, not display infrastructure."
reject_pattern 'UserDefaults' "$VIEWS" \
  "SwiftUI Views must not own persistence."
reject_pattern 'GlassBrightnessControl' "$APP" \
  "The obsolete glass-specific brightness component must not return."

while IFS= read -r -d '' file; do
  lines=$(wc -l < "$file" | tr -d ' ')
  if (( lines > 450 )); then
    relative_path="${file#"$ROOT"/}"
    fail "$relative_path has $lines lines; split the view before it becomes a monolith."
  fi
done < <(find "$VIEWS" -name '*.swift' -print0)

required_previews=(
  'Popover — Detecting'
  'Popover — Empty'
  'Popover — One Hardware Display'
  'Popover — Two Mixed Displays'
  'Popover — Unavailable Control'
  'Popover — Failure'
  'Popover — Eight Displays'
  'Settings — General'
  'Settings — Displays'
  'Settings — Keyboard'
  'Settings — Advanced'
  'Settings — About'
)

for preview in "${required_previews[@]}"; do
  grep -Fq "$preview" "$ROOT/MyMonitor/Debug/FrontendPreviewGallery.swift" \
    || fail "Required deterministic preview is missing: $preview"
done

printf 'Frontend contract validation passed.\n'
