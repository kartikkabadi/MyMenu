#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DDC="$ROOT/MyMonitor/Core/DDCBrightnessBackend.swift"
ROUTER="$ROOT/MyMonitor/Core/DisplayRouter.swift"
ADAPTER="$ROOT/MyMonitor/Presentation/DisplayRouterAdapter.swift"

fail() {
  printf 'Backend concurrency violation: %s\n' "$1" >&2
  exit 1
}

if grep -nE '\.sync[[:space:]]*\{' "$DDC"; then
  fail "DDC transport must never synchronously block its caller."
fi

if grep -n 'Arm64DDC' "$ROUTER"; then
  fail "DisplayRouter must not call the private DDC transport directly."
fi

grep -q 'MyMonitor.globalDDC' "$DDC" \
  || fail "DDC operations must stay on the single serialized worker queue."
grep -q 'writeGeneration' "$DDC" \
  || fail "DDC writes must retain latest-value coalescing."
grep -q 'reconfigurationGeneration' "$ROUTER" \
  || fail "Display reconfiguration must reject stale asynchronous probe results."
grep -q 'isReconfiguring' "$ROUTER" \
  || fail "DisplayRouter must expose asynchronous detection state."
grep -q '\.detecting(cached:' "$ADAPTER" \
  || fail "The adapter must publish cached controls while reconfiguration is in progress."
grep -q 'DDCBrightnessBackend.probe(displayIDs:' "$ROUTER" \
  || fail "DDC capability discovery must use the asynchronous batch probe."
grep -q 'private func restartProbeIfNeeded' "$ADAPTER" \
  || fail "Committed settings must be able to invalidate an older probe generation."

restart_calls=$(grep -c 'restartProbeIfNeeded()' "$ADAPTER")
if (( restart_calls < 5 )); then
  fail "Brightness, range, forget, and reset actions must all protect against stale probes."
fi

printf 'Backend concurrency validation passed.\n'
