#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DDC="$ROOT/MyMonitor/Core/DDCBrightnessBackend.swift"
GAMMA_BACKEND="$ROOT/MyMonitor/Core/GammaBrightnessBackend.swift"
GAMMA_HOLDS="$ROOT/MyMonitor/Core/DisplayGamma.swift"
GAMMA_REGISTRY="$ROOT/MyMonitor/Policies/GammaHoldRegistry.swift"
ROUTER="$ROOT/MyMonitor/Core/DisplayRouter.swift"
ADAPTER="$ROOT/MyMonitor/Presentation/DisplayRouterAdapter.swift"
POLICY="$ROOT/MyMonitor/Policies/DisplayReconfigurationPolicy.swift"

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

[[ -f "$POLICY" ]] \
  || fail "The hardware-free reconfiguration policy is missing."
[[ -f "$GAMMA_REGISTRY" ]] \
  || fail "The hardware-free gamma hold registry is missing."

grep -q 'MyMonitor.globalDDC' "$DDC" \
  || fail "DDC operations must stay on the single serialized worker queue."
grep -q 'writeGeneration' "$DDC" \
  || fail "DDC writes must retain latest-value coalescing."
grep -q 'activeOwnerByDisplay' "$GAMMA_BACKEND" \
  || fail "Gamma replacement must retain per-display ownership."
grep -q 'GammaHoldRegistry<CGDirectDisplayID>' "$GAMMA_HOLDS" \
  || fail "Persistent and temporary gamma holds must share the tested registry."
grep -q 'brightnessByID' "$GAMMA_REGISTRY" \
  || fail "The gamma hold registry must retain independent per-display values."
grep -q 'restoreColorSyncAndReapplyHolds' "$GAMMA_HOLDS" \
  || fail "Global ColorSync restoration must replay every active gamma hold."
grep -q 'CGDisplayRestoreColorSyncSettings' "$GAMMA_HOLDS" \
  || fail "Gamma removal must restore the original ColorSync calibration."
grep -q 'for (displayID, brightness) in holds.brightnessByID' "$GAMMA_HOLDS" \
  || fail "ColorSync restoration must preserve unrelated gamma and mirror holds."
grep -q 'DisplayGamma.restoreColorSyncAndReapplyHolds()' "$GAMMA_BACKEND" \
  || fail "Gamma probe and teardown must use the shared hold replay path."
grep -q 'reconfigurationGeneration' "$ROUTER" \
  || fail "Display reconfiguration must reject stale asynchronous probe results."
grep -q 'isReconfiguring' "$ROUTER" \
  || fail "DisplayRouter must expose asynchronous detection state."
grep -q '\.detecting(cached:' "$ADAPTER" \
  || fail "The adapter must publish cached controls while reconfiguration is in progress."
grep -q 'DDCBrightnessBackend.probe(displayIDs:' "$ROUTER" \
  || fail "DDC capability discovery must use the asynchronous batch probe."
grep -q 'DisplayReconfigurationPolicy.resolvedBrightness' "$ROUTER" \
  || fail "Probe installation must resolve brightness from the latest live state."
grep -q 'live: displays.first' "$ROUTER" \
  || fail "A cached slider value must outrank stale persisted and probed snapshots."

if grep -qE 'let (savedBrightness|currentBrightness): Double\?' "$ROUTER"; then
  fail "Reconfiguration inputs must not freeze mutable brightness snapshots."
fi

grep -q 'router.handleDisplayTopologyChange()' "$ROUTER" \
  || fail "Add/remove callbacks must reconcile topology immediately."

topology_body=$(sed -n '/private func handleDisplayTopologyChange()/,/^  }/p' "$ROUTER")
printf '%s\n' "$topology_body" | grep -q 'removeDisconnectedBackends' \
  || fail "Topology changes must tear down removed backends immediately."
printf '%s\n' "$topology_body" | grep -q 'scheduleReconfigure(force: true)' \
  || fail "Topology changes must debounce only the expensive reprobe."

remove_line=$(printf '%s\n' "$topology_body" | grep -n 'removeDisconnectedBackends' | head -1 | cut -d: -f1)
schedule_line=$(printf '%s\n' "$topology_body" | grep -n 'scheduleReconfigure(force: true)' | head -1 | cut -d: -f1)
if (( remove_line >= schedule_line )); then
  fail "Removed resources must be released before the reprobe is scheduled."
fi

grep -q 'private func restartProbeIfNeeded' "$ADAPTER" \
  || fail "Tier-expanding configuration resets must invalidate an older probe generation."

restart_calls=$(grep -c 'restartProbeIfNeeded()' "$ADAPTER")
if (( restart_calls < 3 )); then
  fail "Forget and reset actions must protect capability discovery from stale eligibility."
fi

printf 'Backend concurrency validation passed.\n'
