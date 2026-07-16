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

## Gamma replacement ownership

Gamma backends register an owner token per display. A stale backend teardown cannot release the curve installed by its replacement. The active owner restores ColorSync state when gamma control is genuinely removed.

## Automated gates

`DisplayReconfigurationPolicyTests` verify:

- live brightness outranks stale persisted and probed snapshots;
- persisted brightness restores a remembered display;
- probed brightness seeds first run;
- missing values default safely;
- the latest range clamps installation;
- removed display IDs are derived from installed and online sets.

`scripts/validate_backend_concurrency.sh` verifies:

- no synchronous dispatch in the DDC transport;
- private DDC APIs remain outside `DisplayRouter`;
- the serialized worker queue remains present;
- latest-value write generations remain present;
- router reconfiguration generations remain present;
- asynchronous detecting state remains exposed;
- the adapter continues to publish cached detecting state;
- reconfiguration continues to use batch DDC probing;
- installation resolves brightness from live state instead of captured mutable snapshots;
- add/remove callbacks enter the immediate topology path;
- disconnected resources are removed before the reprobe is scheduled;
- forget and reset can still restart capability discovery when eligibility changes.

CI runs this alongside presentation tests, the frontend contract, project regeneration, Debug build, Release build, and whitespace validation.

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
- Forced Hardware when DDC is unavailable.
- Forced Software when gamma is unavailable.
- Switch Gamma → Gamma, Gamma → DDC, and Gamma → Shade and confirm ColorSync state is not reset incorrectly.

### Spaces and mirroring

- Extended desktop across Spaces.
- Fullscreen Space.
- Mirrored external display.
- Confirm shade overlays and temporary gamma holds remain correct through backend replacement.

## Known boundary

The persisted identity still derives from `CGDirectDisplayID`. Durable EDID-based identity across topology changes is a separate migration because it affects existing preference keys, mirrored-set identity, DDC service matching, and user data. F15 does not disguise that limitation as solved.
