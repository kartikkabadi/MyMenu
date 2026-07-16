# F15 Asynchronous Display-Control Integration

F15 makes the established frontend responsive and truthful while monitor capability discovery occurs. It changes backend execution and lifecycle, not product anatomy.

## Main-thread boundary

The main actor owns:

- observable display and configuration state;
- native AppKit window/overlay/gamma lifecycle;
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
9. Resolve gamma or shade fallback on the main actor.
10. Atomically install the final backend set and publish `ready`.

A hot-plug or explicit retry that occurs during an older probe increments the generation. The older result is invalidated and cannot replace newer state.

A probe also captures brightness, range, and requested-control configuration when it starts. If the user commits a new brightness value, changes the allowed range, forgets one display, or resets all display preferences while probing is active, the adapter immediately starts a newer forced generation. The earlier probe cannot later reinstall its captured pre-change state.

## DDC writes

Every DDC connection uses the same global serial queue because the adapted transport maintains shared IOAV service state.

During slider drag:

- frontend presentation updates immediately;
- router state updates immediately;
- DDC requests are latest-value coalesced for 90 ms;
- obsolete generations do not write;
- final release persists immediately in app state while the hardware write remains asynchronous;
- committing through a cached control invalidates any older probe generation before it can install stale brightness.

The probe result carries the already validated service and luminance range into the installed backend, avoiding another synchronous discovery pass.

## Gamma replacement ownership

Gamma backends register an owner token per display. A stale backend teardown cannot release the curve installed by its replacement. The active owner restores ColorSync state when gamma control is genuinely removed.

## Automated gates

`scripts/validate_backend_concurrency.sh` verifies:

- no synchronous dispatch in the DDC transport;
- private DDC APIs remain outside `DisplayRouter`;
- the serialized worker queue remains present;
- latest-value write generations remain present;
- router reconfiguration generations remain present;
- asynchronous detecting state remains exposed;
- the adapter continues to publish cached detecting state;
- reconfiguration continues to use batch DDC probing;
- committed brightness, range, forget, and reset actions continue to invalidate stale probes.

CI runs this alongside presentation tests, the frontend contract, Debug build, Release build, and whitespace validation.

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
- Trigger Retry twice rapidly.
- Change the requested control method during a retry.
- Change minimum/maximum range during a retry.
- Forget a display or reset all display preferences during a retry.
- Sleep/wake during detection.
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
