# F15 Asynchronous Display-Control Integration

F15 makes the established native frontend responsive and truthful while monitor capability discovery occurs. It changes backend execution, routing, and lifecycle—not product anatomy.

## Execution boundaries

The main actor owns:

- observable display and configuration state;
- AppKit window, overlay, and gamma lifecycle;
- persistence reads and writes;
- generation checks and atomic backend installation;
- presentation snapshots;
- callback and notification-observer ownership.

The serialized `MyMonitor.globalDDC` worker queue owns:

- IOAV service matching;
- DDC luminance reads and no-op write validation;
- range discovery;
- latest-value-coalesced writes;
- stale-service rematching;
- DDC connection invalidation.

No DDC operation synchronously blocks its caller.

## Reconfiguration lifecycle

1. Enumerate current external display IDs.
2. Preserve still-connected backends and cached presentation rows.
3. Remove disconnected resources immediately.
4. Publish `detecting(cached:)`.
5. Batch-probe eligible DDC displays on the worker queue.
6. Return opaque validated results to the main actor.
7. Reject stale generations and results arriving after teardown.
8. Recheck the online display set.
9. Resolve the latest requested method, range, and fallback.
10. Resolve brightness from live state, persisted state, probed hardware, then full brightness.
11. Atomically install the final backend set and publish `ready`.

Hot-plug, display-mode, and mirror changes invalidate the active generation immediately. Disconnected rows, temporary mirror/Space holds, backends, and queued writes are released before the 600 ms capability-reprobe debounce.

Wake bypasses that debounce and starts a forced generation immediately, so pre-sleep IOAV results cannot install during a post-wake delay.

Forget and Reset return the requested method to Automatic and force a new generation for connected displays. The UI therefore cannot report Automatic while retaining a previously forced Hardware, Software, or Shade backend.

## Terminal lifetime ownership

`AppDelegate` performs synchronous, idempotent teardown for both the explicit Quit action and `applicationWillTerminate`.

`DisplayRouter.teardownAll()` is a terminal boundary. It:

- unregisters the Core Graphics reconfiguration callback that holds an unretained router pointer;
- removes block observers from both `NotificationCenter.default` and the workspace notification center;
- cancels pending reprobe and overlay-transition work;
- invalidates queued DDC work;
- restores gamma/ColorSync state and closes Shade panels;
- rejects any callback, timer, user action, or late probe that arrives afterward.

Teardown is not scheduled from a termination notification because the process may exit before an asynchronously enqueued task executes.

## Mirroring

Rows collapse only for a true full-mirror topology. A partially mirrored set plus an unrelated extended display remains fully represented.

A collapsed row is a control group, not merely a visual representative. Brightness changes fan out to every connected external member of the full mirror set. Each physical display still clamps against and persists its own configured range.

A global hotkey targeting a connected physical display that becomes hidden by full-mirror collapse is routed through the visible representative; the router then fans that value out to the complete set. Remembered disconnected targets remain inactive rather than being redirected unexpectedly.

Temporary gamma stabilization is applied only to actual members of the mirror set. Routing changes cancel the transition timer and release the complete temporary hold set before backend reconciliation.

## DDC writes and recovery

During slider drag:

- frontend and router state update immediately;
- writes are coalesced for 90 ms;
- obsolete write generations do not execute;
- final release persists app state while hardware communication remains asynchronous;
- probe installation reads current live state, so it cannot roll brightness backward.

A probe result carries its validated service, confirmed maximum, and current luminance into the installed backend.

If a service or range read fails after wake or a topology change, the same latest requested value receives one bounded recovery attempt:

1. discard the stale service and range state;
2. rematch the IOAV service;
3. reread the range;
4. retry the write once.

There is no retry loop and no replay of an obsolete generation. An unreadable range blocks the write rather than assuming a monitor maximum.

## Shade correctness

Shade opacity animations carry a monotonically increasing generation. An older completion cannot hide the panel after a newer dim command. Direct manipulation and teardown remove in-flight layer animations, and a torn-down backend cannot recreate or reorder its panel.

## Gamma and ColorSync

Gamma backends retain an owner token per display. A stale backend cannot release a replacement curve.

Construction does not write a temporary 100% curve, avoiding replacement flashes.

`CGDisplayRestoreColorSyncSettings()` is process-global. Persistent gamma controls and temporary mirror/Space holds therefore share one `GammaHoldRegistry`. Related holds are removed atomically, ColorSync is restored once, and every remaining hold is replayed immediately. Writing an identity gamma curve is not treated as calibration restoration.

## Settings and global shortcuts

Carbon replacement is destructive: current registrations must be removed before candidate shortcuts can be installed. If candidate registration fails, `KeyboardShortcutController` reinstalls the previous working registration set and leaves persisted configuration unchanged.

Forgetting a display publishes its identity to dependent settings state. A matching hotkey target is normalized to Display under pointer, preventing an invisible forgotten ID from becoming a permanent no-op. Reset All applies the same rule to every removed identity.

## IORegistry and IOAV safety

The adapted matcher:

- releases skipped and consumed iterator objects;
- initializes, bounds-checks, deinitializes, and deallocates the registry path buffer;
- ignores failed path extraction instead of reading uninitialized memory;
- clears proxy-specific service state before lookup;
- appends only validated external candidates;
- preserves framebuffer identity across multiple proxies by creating an isolated candidate per proxy;
- guards root and iterator ownership before release.

## Hardware-free policies and tests

`MyMonitorPolicies` covers:

- live/persisted/probed brightness precedence;
- latest-range clamping;
- disconnected-ID calculation;
- full-vs-partial mirror presentation;
- full-mirror control fan-out;
- independent gamma holds and atomic hold-set removal.

Presentation tests additionally cover destructive hotkey-registration rollback, forgotten-display target reconciliation, and cached-state behavior during asynchronous detection.

## Executable gates

Exact-head CI requires:

- SwiftPM tests with warnings as errors;
- frontend contract validation;
- backend concurrency, lifecycle, recovery, and resource validation;
- deterministic Xcode project regeneration with zero committed-project drift;
- Xcode 26.3 arm64 Debug and Release builds with Swift warnings as errors;
- whitespace validation.

Checkout credentials are not persisted into the workspace while PR-controlled scripts execute.

## Required hardware validation

### Launch and continuous adjustment

- first launch reads current DDC luminance without a visible jump;
- the popover opens immediately during probing;
- rapid drag remains responsive and never reverses through stale writes;
- final brightness persists after relaunch;
- a cached drag during Retry is not rolled back.

### Recovery and lifecycle

- the first command after wake succeeds through bounded service rematching;
- hot-plug/unplug during probing does not resurrect rows or writes;
- repeated Retry, method changes, range changes, Forget, and Reset reject stale generations;
- ordinary Quit and system termination restore gamma state and close Shade panels;
- no callback restarts routing after teardown.

### Mixed backends and topology

- DDC + Gamma, DDC + Shade, and two simultaneous Gamma displays;
- Gamma-to-Gamma replacement without a 100% flash;
- Hardware/Software/Shade fallback transitions;
- extended desktop and fullscreen Spaces;
- a full mirror with multiple external displays adjusts every physical member from one row;
- a mirrored pair plus an extended display keeps the unrelated display visible;
- unplug during mirror/Space stabilization leaves no built-in or peer gamma hold.

## Known boundary

Persistence still derives from `CGDirectDisplayID`. Durable EDID-based identity requires a separate migration because it affects preference keys, mirror-set identity, DDC matching, and existing user data. F15 does not disguise that limitation as solved.
