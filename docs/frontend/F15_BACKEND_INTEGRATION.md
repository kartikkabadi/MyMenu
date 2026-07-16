# F15 Asynchronous Display-Control Integration

F15 makes the established frontend responsive and truthful while monitor capability discovery occurs. It changes backend execution and lifecycle, not product anatomy.

## Main-thread boundary

The main actor owns:

- observable display and configuration state;
- native AppKit window, overlay, and gamma lifecycle;
- persistence reads and writes;
- generation checks and atomic backend-set installation;
- presentation snapshots.

The serialized DDC worker queue owns:

- IOAV service matching;
- DDC luminance reads;
- no-op write validation;
- range discovery;
- debounced luminance writes;
- DDC connection invalidation and rematching.

No DDC operation may synchronously block its caller.

## Reconfiguration lifecycle

1. Enumerate the current external display IDs.
2. Preserve still-connected active backends and cached presentation rows.
3. Remove disconnected backend resources immediately.
4. Publish `detecting(cached:)` through the adapter.
5. Batch-probe DDC candidates on `MyMonitor.globalDDC`.
6. Return probe results to the main actor.
7. Reject results whose reconfiguration generation is stale.
8. Recheck the online display set before applying results.
9. Resolve the latest requested method, range, and gamma or shade fallback on the main actor.
10. Resolve installation brightness from live state, then persisted state, then probed hardware state.
11. Atomically install the final backend set and publish `ready`.

A hot-plug or explicit retry that occurs during an older probe increments the generation. The older result is invalidated and cannot replace newer state.

Add/remove callbacks do not wait for the 600 ms stabilization debounce. They immediately invalidate the active generation, terminate any mirror/Space transition holds, remove disconnected rows, tear down disconnected backends, and cancel queued DDC writes. Only the expensive reprobe is delayed so a burst of Core Graphics callbacks settles into one generation.

Wake bypasses the debounce and starts a forced generation immediately. A probe that began before sleep therefore cannot install stale IOAV service state during a post-wake delay.

Brightness and range are deliberately not frozen into a probe input. At installation, the hardware-free `DisplayReconfigurationPolicy` chooses the current in-memory value first, then the latest persisted value, then the probed luminance, and finally full brightness. It clamps the result against the latest configured range. A cached slider drag therefore cannot be rolled back by a probe that started earlier.

Forget and Reset change the requested control method back to Automatic. Connected displays are always re-probed immediately, even when the router was previously ready, so the UI cannot report Automatic while retaining a formerly forced Hardware, Software, or Shade backend.

## Mirroring

The popover collapses rows only for a true full-mirror topology. A partially mirrored set plus an unrelated extended display remains fully represented.

Mirror detection requires both:

- one effective `NSScreen` surface; and
- at least one Core Graphics display in a mirror set.

Temporary gamma stabilization is applied only to actual members of that mirror set. A topology change cancels the transition timer and releases the complete temporary hold set before backend reconciliation.

## DDC writes and recovery

Every DDC connection uses the same global serial queue because the adapted transport maintains shared IOAV service state.

During slider drag:

- frontend presentation updates immediately;
- router state updates immediately;
- DDC requests are latest-value coalesced for 90 ms;
- obsolete write generations do not write;
- final release persists immediately in app state while the hardware write remains asynchronous;
- probe installation reads the live router value, so it cannot reinstall pre-drag brightness;
- the installed connection receives the final value before the debounce expires, cancelling any stale scheduled write.

The probe result carries the already validated service and confirmed luminance range into the installed backend. A failed later write discards the cached service and range state; the next user request rematches the IOAV service and re-reads the range instead of pinning a stale post-wake or post-topology handle indefinitely. A range read failure blocks the write rather than assuming a monitor maximum.

The adapted IOKit matcher releases both skipped and returned iterator objects after extraction and deallocates its registry-path buffer. Repeated probes therefore do not leak one registry object or heap buffer per match attempt.

## Gamma replacement and ColorSync

Gamma backends retain an owner token per display. A stale backend teardown cannot release the curve installed by its replacement.

Backend construction no longer writes a temporary 100% curve before the desired brightness is known. This avoids a visible flash during Gamma-to-Gamma replacement.

`CGDisplayRestoreColorSyncSettings()` is process-global rather than display-scoped. Persistent gamma controls and temporary mirror/Space stabilization holds therefore share one `GammaHoldRegistry`. Hold removal follows one guarded operation:

1. remove the complete related hold set from the registry;
2. restore the system ColorSync calibration once;
3. immediately replay every persistent and temporary gamma hold that remains registered.

Writing an identity gamma curve is not treated as calibration restoration. This preserves the removed display's ColorSync calibration without brightening another gamma-controlled display or dropping an in-flight mirror/Space hold.

## Hardware-free policies

Mutable installation, topology, and replay rules live in the small `MyMonitorPolicies` SwiftPM target rather than in UI or hardware code:

- `DisplayReconfigurationPolicy` defines live/persisted/probed brightness precedence, topology subtraction, and full-vs-partial mirror presentation;
- `GammaHoldRegistry` owns independent normalized brightness values and atomic hold-set removal.

The app target compiles these policies as internal source, while SwiftPM exercises them without Core Graphics, IOAV, AppKit windows, or a connected monitor.

## Automated gates

`DisplayReconfigurationPolicyTests` verify:

- live brightness outranks stale persisted and probed snapshots;
- persisted brightness restores a remembered display;
- probed brightness seeds first run;
- missing values default safely;
- the latest range clamps installation;
- removed display IDs are derived from installed and online sets;
- partial mirroring preserves unrelated displays;
- full mirroring collapses to one stable representative.

`GammaHoldRegistryTests` verify:

- multiple displays retain independent brightness values;
- replacing one hold does not alter another;
- removing one hold preserves every other hold;
- related transition holds can be removed atomically;
- values remain normalized to `0...1`.

`scripts/validate_backend_concurrency.sh` verifies:

- no synchronous dispatch in the DDC transport;
- private DDC APIs remain outside `DisplayRouter`;
- the serialized worker queue and latest-write generations remain present;
- failed DDC services are discarded and unvalidated ranges block writes;
- gamma construction cannot flash to full brightness;
- global ColorSync restoration is paired with atomic hold removal and replay;
- router reconfiguration generations remain present;
- asynchronous detecting state remains exposed;
- installation resolves brightness from live state instead of captured mutable snapshots;
- full-vs-partial mirror policy remains wired into the router;
- topology changes release transition holds and disconnected resources before reprobe scheduling;
- wake invalidates the active generation immediately;
- Forget and Reset force reconciliation for connected displays;
- IOKit iterator objects and allocated path buffers remain balanced.

CI additionally enforces:

- SwiftPM tests with warnings as errors;
- the frontend contract;
- deterministic Xcode project regeneration with zero committed-project drift;
- Xcode 26.3 arm64 Debug and Release builds with Swift warnings as errors;
- whitespace validity.

The committed `MyMonitor.xcodeproj` is therefore the exact output of `scripts/generate_xcodeproj.sh`; opening the repository locally and building in CI use the same source graph.

## Required hardware validation

### Launch and first detection

- Launch with one DDC monitor and confirm the menu-bar app remains responsive during probing.
- Open the popover immediately after launch and confirm the detecting state appears rather than a frozen click.
- Confirm first launch reads current hardware luminance and does not visibly change it.

### Continuous adjustment and recovery

- Drag rapidly from low to high brightness and back.
- Confirm the thumb and percentage remain frame-responsive.
- Confirm hardware follows without reversing or replaying stale intermediate values.
- Release at a final value and confirm persistence after relaunch.
- Adjust through a cached row during Retry and confirm probe completion does not roll the display back.
- Sleep and wake, then confirm a stale IOAV handle rematches after the next request.

### Reconfiguration races

- Connect and disconnect a monitor while another monitor is being probed.
- Confirm a removed row disappears immediately, before reprobe completion.
- Confirm no queued write reaches a monitor after its backend is torn down.
- Trigger Retry twice rapidly.
- Change the requested control method during a retry.
- Change minimum or maximum range during a retry.
- Forget one connected display and Reset All while ready; confirm the active method is reselected immediately.
- Sleep and wake during detection.
- Confirm stale rows, brightness, bounds, preferences, or backends do not reappear.

### Mixed backends

- One DDC display plus one gamma display.
- One DDC display plus one shade display.
- Two simultaneous gamma displays at different brightness levels.
- Probe or remove one gamma display and confirm the other curve is immediately preserved.
- Confirm Gamma-to-Gamma replacement does not flash to 100% brightness.
- Trigger a mirror/Space hold while restoring ColorSync and confirm the temporary hold is replayed.
- Forced Hardware when DDC is unavailable.
- Forced Software when gamma is unavailable.
- Switch Gamma → Gamma, Gamma → DDC, and Gamma → Shade and confirm ColorSync calibration and remaining active curves stay correct.

### Spaces and mirroring

- Extended desktop across Spaces.
- Fullscreen Space.
- Fully mirrored external display.
- A mirrored pair plus a second extended display; confirm the second display remains visible in the popover.
- Unplug during a mirror/Space transition; confirm no built-in or peer gamma hold remains after topology reconciliation.

## Known boundary

The persisted identity still derives from `CGDirectDisplayID`. Durable EDID-based identity across topology changes is a separate migration because it affects existing preference keys, mirrored-set identity, DDC service matching, and user data. F15 does not disguise that limitation as solved.
