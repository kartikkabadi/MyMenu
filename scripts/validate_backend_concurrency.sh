#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DELEGATE="$ROOT/MyMonitor/AppDelegate.swift"
DDC="$ROOT/MyMonitor/Core/DDCBrightnessBackend.swift"
GAMMA_BACKEND="$ROOT/MyMonitor/Core/GammaBrightnessBackend.swift"
GAMMA_HOLDS="$ROOT/MyMonitor/Core/DisplayGamma.swift"
OVERLAY="$ROOT/MyMonitor/Core/OverlayBrightnessBackend.swift"
GAMMA_REGISTRY="$ROOT/MyMonitor/Policies/GammaHoldRegistry.swift"
ROUTER="$ROOT/MyMonitor/Core/DisplayRouter.swift"
ADAPTER="$ROOT/MyMonitor/Presentation/DisplayRouterAdapter.swift"
SHORTCUT_CONTROLLER="$ROOT/MyMonitor/Presentation/KeyboardShortcutController.swift"
POLICY="$ROOT/MyMonitor/Policies/DisplayReconfigurationPolicy.swift"
ARM64_DDC="$ROOT/MyMonitor/ThirdParty/Arm64DDC.swift"
SHORTCUT_TESTS="$ROOT/MyMonitorTests/Presentation/KeyboardShortcutControllerTests.swift"

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

[[ -f "$POLICY" ]] || fail "The hardware-free reconfiguration policy is missing."
[[ -f "$GAMMA_REGISTRY" ]] || fail "The hardware-free gamma hold registry is missing."

grep -q 'MyMonitor.globalDDC' "$DDC" \
  || fail "DDC operations must stay on the single serialized worker queue."
grep -q 'writeGeneration' "$DDC" \
  || fail "DDC writes must retain latest-value coalescing."
grep -q 'self.service = nil' "$DDC" \
  || fail "A failed DDC service must be discarded so a later request can rematch it."
grep -q 'private func readRangeIfNeeded.*-> Bool' "$DDC" \
  || fail "Unvalidated DDC ranges must prevent a write instead of assuming a maximum."

grep -q 'activeOwnerByDisplay' "$GAMMA_BACKEND" \
  || fail "Gamma replacement must retain per-display ownership."
if grep -q 'applyBrightnessHold(1.0' "$GAMMA_BACKEND"; then
  fail "Gamma backend construction must not flash a display to full brightness before installation."
fi
grep -q 'GammaHoldRegistry<CGDirectDisplayID>' "$GAMMA_HOLDS" \
  || fail "Persistent and temporary gamma holds must share the tested registry."
grep -q 'releaseHolds' "$GAMMA_HOLDS" \
  || fail "Related gamma holds must be released through one ColorSync restore."
grep -q 'CGDisplayRestoreColorSyncSettings' "$GAMMA_HOLDS" \
  || fail "Gamma removal must restore the original ColorSync calibration."
grep -q 'for (displayID, brightness) in holds.brightnessByID' "$GAMMA_HOLDS" \
  || fail "ColorSync restoration must preserve unrelated gamma and mirror holds."
grep -q 'DisplayGamma.releaseHold(displayID:' "$GAMMA_BACKEND" \
  || fail "Active gamma teardown must remove its registered hold."

# Shade animations can complete after a newer command. Every completion must prove it still owns
# the latest generation, and direct manipulation must cancel in-flight layer animations.
grep -q 'animationGeneration' "$OVERLAY" \
  || fail "Shade animations must retain a latest-command generation."
grep -q 'generation == self.animationGeneration' "$OVERLAY" \
  || fail "A stale shade completion must not hide the panel after a newer dim command."
grep -q 'removeAllAnimations' "$OVERLAY" \
  || fail "Direct shade updates and teardown must cancel in-flight animations."
grep -q 'guard !hasTornDown' "$OVERLAY" \
  || fail "A torn-down shade backend must not recreate or reorder its panel."

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
grep -q 'DisplayReconfigurationPolicy.presentationIDs' "$ROUTER" \
  || fail "Mirror presentation must distinguish full mirroring from partial mirroring."

if grep -qE 'let (savedBrightness|currentBrightness): Double\?' "$ROUTER"; then
  fail "Reconfiguration inputs must not freeze mutable brightness snapshots."
fi

grep -q 'router.handleDisplayRoutingChange()' "$ROUTER" \
  || fail "Add/remove and display-mode callbacks must enter the routing reconciliation path."
grep -q 'flags.contains(.desktopShapeChangedFlag) || flags.contains(.setModeFlag)' "$ROUTER" \
  || fail "Mirror and display-mode changes must force backend reselection."

screen_body=$(sed -n '/private func registerScreenObservers()/,/private func registerWakeObserver()/p' "$ROUTER")
printf '%s\n' "$screen_body" | grep -q 'didChangeScreenParametersNotification' \
  || fail "The screen-parameter fallback observer is missing."
printf '%s\n' "$screen_body" | grep -q 'handleDisplayRoutingChange()' \
  || fail "Screen-parameter changes must reconcile backend routing and presentation rows."

routing_body=$(sed -n '/private func handleDisplayRoutingChange()/,/^  }/p' "$ROUTER")
printf '%s\n' "$routing_body" | grep -q 'endOverlaySpaceTransition()' \
  || fail "Routing changes must terminate temporary gamma holds immediately."
printf '%s\n' "$routing_body" | grep -q 'removeDisconnectedBackends' \
  || fail "Routing changes must tear down removed backends immediately."
printf '%s\n' "$routing_body" | grep -q 'scheduleReconfigure(force: true)' \
  || fail "Routing changes must debounce only the expensive reprobe."

end_line=$(printf '%s\n' "$routing_body" | grep -n 'endOverlaySpaceTransition' | head -1 | cut -d: -f1)
remove_line=$(printf '%s\n' "$routing_body" | grep -n 'removeDisconnectedBackends' | head -1 | cut -d: -f1)
schedule_line=$(printf '%s\n' "$routing_body" | grep -n 'scheduleReconfigure(force: true)' | head -1 | cut -d: -f1)
if (( end_line >= remove_line || remove_line >= schedule_line )); then
  fail "Transition holds and removed resources must be released before the reprobe is scheduled."
fi

wake_body=$(sed -n '/private func registerWakeObserver()/,/^  }/p' "$ROUTER")
printf '%s\n' "$wake_body" | grep -q 'reconfigure(force: true)' \
  || fail "Wake must invalidate the active generation immediately."
if printf '%s\n' "$wake_body" | grep -q 'scheduleReconfigure'; then
  fail "Wake must not leave a pre-sleep probe valid during a debounce window."
fi

# Termination must release gamma and shade state synchronously. Scheduling teardown from a
# will-terminate notification is too late because the process may exit before that task runs.
grep -q 'func applicationWillTerminate' "$APP_DELEGATE" \
  || fail "Application termination must synchronously enter the teardown path."
grep -q 'private var hasTornDown' "$APP_DELEGATE" \
  || fail "Application teardown must be idempotent across Quit and willTerminate callbacks."
quit_body=$(sed -n '/func quitApp()/,/^  }/p' "$APP_DELEGATE")
printf '%s\n' "$quit_body" | grep -q 'teardown()' \
  || fail "The explicit Quit action must use the shared synchronous teardown path."
printf '%s\n' "$quit_body" | grep -q 'NSApp.terminate' \
  || fail "The explicit Quit action must still terminate the application."

# Global hotkey replacement is destructive on Carbon. A failed candidate must reinstall the last
# working configuration rather than leaving the user with no active shortcuts.
grep -q 'register(candidate, restoring: configuration)' "$SHORTCUT_CONTROLLER" \
  || fail "Shortcut edits must retain the previous working configuration for rollback."
grep -q 'try? replaceRegistrations(with: previous)' "$SHORTCUT_CONTROLLER" \
  || fail "Failed shortcut replacement must reinstall the previous registrations."
grep -q 'clearsRegistrationsBeforeThrow = true' "$SHORTCUT_TESTS" \
  || fail "Tests must model a destructive platform registration failure."
grep -q 'XCTAssertEqual(service.registrations, initial.registrations)' "$SHORTCUT_TESTS" \
  || fail "Tests must prove working hotkeys survive a failed replacement."

# The adapted IOKit matcher runs on every DDC reprobe; ownership and extracted state must be safe.
grep -q 'cpath.initialize(repeating: 0' "$ARM64_DDC" \
  || fail "The IORegistry path buffer must be initialized before a possible failed path lookup."
grep -q 'IORegistryEntryGetPath.*== KERN_SUCCESS' "$ARM64_DDC" \
  || fail "A failed IORegistry path lookup must not be converted from uninitialized memory."
grep -q 'cpath.deinitialize' "$ARM64_DDC" \
  || fail "The initialized IORegistry path buffer must be deinitialized."
grep -q 'IOObjectRelease(entry)' "$ARM64_DDC" \
  || fail "Skipped IORegistry iterator entries must be released."
grep -q 'IOObjectRelease(objectOfInterest.entry)' "$ARM64_DDC" \
  || fail "Matched IORegistry iterator entries must be released after extraction."
grep -q 'ioregService.service = nil' "$ARM64_DDC" \
  || fail "Each DCPAV proxy lookup must clear a previous service handle first."
grep -q 'if candidate.service != nil' "$ARM64_DDC" \
  || fail "Only validated external IOAV service candidates may enter DDC matching."
grep -q 'var candidate = framebufferService' "$ARM64_DDC" \
  || fail "Each IOAV proxy must use isolated state while retaining framebuffer identity."

printf 'Backend concurrency validation passed.\n'
