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
- first-write range discovery;
- debounced luminance writes;
- DDC connection invalidation.

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

Add/remove callbacks do not wait for the 600 ms stabilization debounce. They immediately invalidate the active generation, remove disconnected rows, tear down disconnected backends, and cancel their queued DDC writes. Only the expensive reprobe is delayed so a burst of Core Graphics callbacks settles into one generation.

Brightness and range are deliberately not frozen into a probe input. At installation, the hardware-free `DisplayReconfigurationPolicy` chooses the current in-memory value first, then the latest persisted value, then the probed luminance, and finally full brightness. It clamps the result against the latest configured range. A cached slider drag therefore cannot be rolled back by a probe that started earlier.

Forget and reset can expand which control tiers are eligible. If either occurs during detection, the adapter starts a newer generation so DDC eligibility is recomputed rather than merely applying newer values to an incomplete candidate set.

## DDC writes

Every DDC connection uses the same global serial queue because the adapted transport maintains shared IOAV service state.

During slider drag:

- frontend presentation updates immediately;
- router state updates immediately;
- DDC requests are latest-value coalesced for 90 ms;
- obsolete write generations do not write;
- final release persists immediately in app state while the hardware write remains asynchronous;
- probe installation reads the live router value, so it cannot reinstall pre-drag brightness;
- the installed connection receives the final value before the debounce expires, cancelling any stale scheduled write.

The probe result carries the already validated service and luminance range into the installed backend, avoiding another synchronous discovery pass.

## Gamma replacement and ColorSync

Gamma backends retain an owner token per display. A stale backend teardown cannot release the curve installed by its replacement.

`CGDisplayRestoreColorSyncSettings()` is process-global rather than display-scoped. Persistent gamma controls and temporary mirror/Space stabilization holds therefore share one `GammaHoldRegistry`. Probe cleanup and active-owner teardown follow one guarded operation:

1. restore the system ColorSync calibration;
2. remove only the hold whose active owner is actually ending, when applicable;
3. immediately replay every persistent and temporary gamma hold that remains registered.

This restores the removed display correctly without brightening another gamma-controlled display or dropping an in-flight mirror/Space hold. A stale owner performs neither the global restore nor replay.

## Hardware-free policies

Mutable installation and replay rules live in the small `MyMonitorPolicies` SwiftPM target rather than in UI or hardware code:

- `DisplayReconfigurationPolicy` defines live/persisted/probed brightness precedence and topology subtraction;
- `GammaHoldRegistry` owns independent normalized brightness values for all active holds.

The app target compiles these policies as internal source, while SwiftPM exercises them without Core Graphics, IOAV, AppKit windows, or a connected monitor.

## Automated gates

`DisplayReconfigurationPolicyTests` verify:

- live brightness outranks stale persisted and probed snapshots;
- persisted brightness restores a remembered display;
- probed brightness seeds first run;
- missing values default safely;
- the latest range clamps installation;
- removed display IDs are derived from installed and online sets.

`GammaHoldRegistryTests` verify:

- multiple displays retain independent brightness values;
- replacing one hold does not alter another;
- removing one hold preserves every other hold;
- values remain normalized to `0...1`.

`scripts/validate_backend_concurrency.sh` verifies:

- no synchronous dispatch in the DDC transport;
- private DDC APIs remain outside `DisplayRouter`;
- the serialized worker queue and latest-write generations remain present;
- gamma owner and shared hold-replay state remain present;
- global ColorSync restoration is paired with replay of every active gamma and mirror hold;
- router reconfiguration generations remain present;
- asynchronous detecting state remains exposed;
- the adapter continues to publish cached detecting state;
- reconfiguration continues to use batch DDC probing;
- installation resolves brightness from live state instead of captured mutable snapshots;
- add/remove callbacks enter the immediate topology path;
- disconnected resources are removed before the reprobe is scheduled;
- forget and reset can still restart capability discovery when eligibility changes.

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

### Continuous adjustment

- Drag rapidly from low to high brightness and back.
- Confirm the thumb and percentage remain frame-responsive.
- Confirm hardware follows without reversing or replaying stale intermediate values.
- Release at a final value and confirm persistence after relaunch.
- Adjust through a cached row during Retry and confirm probe completion does not roll the display back.

### Reconfiguration races

- Connect and disconnect a monitor while another monitor is being probed.
- Confirm a removed row disappears immediately, before reprobe completion.
- Confirm no queued write reaches a monitor after its backend is torn down.
- Trigger Retry twice rapidly.
- Change the requested control method during a retry.
- Change minimum or maximum range during a retry.
- Forget a display or reset all display preferences during a retry.
- Sleep and wake during detection.
- Confirm stale rows, brightness, bounds, preferences, or backends do not reappear.

### Mixed backends

- One DDC display plus one gamma display.
- One DDC display plus one shade display.
- Two simultaneous gamma displays at different brightness levels.
- Probe or remove one gamma display and confirm the other curve is immediately preserved.
- Trigger a mirror/Space hold while restoring ColorSync and confirm the temporary hold is replayed.
- Forced Hardware when DDC is unavailable.
- Forced Software when gamma is unavailable.
- Switch Gamma → Gamma, Gamma → DDC, and Gamma → Shade and confirm ColorSync calibration and remaining active curves stay correct.

### Spaces and mirroring

- Extended desktop across Spaces.
- Fullscreen Space.
- Mirrored external display.
- Confirm shade overlays and temporary gamma holds remain correct through backend replacement.

## Known boundary

The persisted identity still derives from `CGDirectDisplayID`. Durable EDID-based identity across topology changes is a separate migration because it affects existing preference keys, mirrored-set identity, DDC service matching, and user data. F15 does not disguise that limitation as solved.
