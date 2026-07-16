# Backend Product Contract

This document defines the user-visible semantics of the local display-control engine. It is intentionally stricter than an implementation description: code may change, but these behaviors remain binding until a decision record changes them.

## 1. Scope

MyMonitor controls brightness for connected external displays.

Included:

- display discovery;
- durable local display identity;
- Apple-native brightness when available;
- DDC/CI luminance control;
- Gamma-based software dimming when safe;
- Shade fallback when no better method is safe;
- per-display desired brightness and allowed range;
- method preference and truthful active-method reporting;
- hot-plug, wake, mirroring, mode-change, and teardown recovery;
- privacy-scoped diagnostics;
- local persistence.

Excluded:

- volume and mute;
- contrast and color gain;
- input switching;
- monitor power commands;
- automatic ambient-light adaptation;
- schedules;
- XDR/HDR brightness boosting;
- resolution, refresh rate, rotation, color profile, or EDID overrides;
- virtual displays;
- network display control;
- cloud sync, accounts, analytics, or remote configuration;
- a privileged helper, daemon, driver, or kernel extension.

## 2. User-facing brightness invariant

Every public brightness value is normalized to `0...1`:

- `0` means the darkest value MyMonitor is allowed to request through the selected method.
- `1` means the brightest value MyMonitor is allowed to request through the selected method.

The configured per-display minimum and maximum further constrain that range.

The engine never reverses slider direction when switching methods. Monitor-specific DDC ranges, native ranges, Gamma multipliers, and Shade alpha are internal transformations.

## 3. Brightness concepts

The engine maintains these values independently and scopes intent to a control domain.

### Control domain

```swift
enum BrightnessControlDomain: String, Codable, Sendable {
  case hardware
  case gamma
  case shade
}
```

Apple Native and DDC share the hardware domain because both represent physical backlight intent. Gamma and Shade retain separate software-attenuation intent. A normalized value from one domain is not assumed equivalent to the same value in another domain.

### Desired brightness

The latest value intentionally committed by the user or requested by an explicit lifecycle policy for one control domain. A profile may remember one desired value per domain, but only the active domain is presented as the current slider value. Desired state may be newer than confirmed state.

### Observed brightness

The latest value confirmed from hardware or from a locally owned deterministic software method.

- Apple Native: confirmed by successful API result and readback where supported.
- DDC: confirmed by a read or bounded post-write verification.
- Gamma: confirmed when the composed table is successfully installed under the current owner.
- Shade: confirmed when the owned window state has been applied.

### Presented brightness

The frontend’s immediate value. During direct manipulation it may optimistically reflect the pointer before observed state catches up.

The engine must never overwrite observed state merely because a write was queued or attempted.

### Confirmed continuity target

The process-local, domain-scoped brightness value that may be restored automatically after wake or a proven transient reconnect. It records the control domain, compatible method/resource evidence, normalized value, and observation that established it.

It is updated only by:

- a reliable non-mutating observation adopted as the stable session state; or
- a committed desired value that was subsequently confirmed applied.

A failed, provisional, queued, writing, accepted-but-unverified, or otherwise unverified desired value does not replace it. A continuity target is never replayed through a different control domain without a separately qualified conversion policy. Adopting observed hardware state as a continuity target does not by itself overwrite the persisted user preference.

## 4. Write-status vocabulary

Every connected session exposes one write status:

```swift
public enum BrightnessWriteStatus: Equatable, Sendable {
  case idle
  case queued(operationID: UUID)
  case writing(operationID: UUID, attempt: Int)
  case acceptedUnverified(operationID: UUID, desired: Double)
  case applied(operationID: UUID, observed: Double)
  case failed(operationID: UUID, failure: ControlFailure, desired: Double)
}
```

The production model may use smaller internal types, but it must preserve the same distinctions.

Rules:

- A slider drag may generate many desired updates but only the newest pending value remains eligible to write.
- Releasing the slider commits one final desired value.
- A later operation supersedes an older operation for the same physical control resource.
- An obsolete operation cannot publish success, failure, or observed state.
- A failed operation does not erase the desired value.
- A failed operation does not claim the desired value was applied.
- A failed or provisional operation does not become the automatic wake/reconnect restore target.
- `acceptedUnverified` means the transport accepted the command but no trustworthy observation proved the resulting state. It does not update observed brightness or the confirmed continuity target.
- `applied` always carries evidence-backed observed state.

## 5. Startup and continuity policy

The engine must identify why a display is being configured.

```swift
enum ReconfigurationReason {
  case coldLaunch
  case firstConnection
  case transientReconnect(continuity: ContinuityToken)
  case wake(continuity: ContinuityToken)
  case topologyChanged
  case displayModeChanged
  case userRetry
  case methodChanged
  case profileChanged
  case testFixture
}
```

An equivalent model is acceptable. A generic `force: Bool` is not.

### Cold launch

- Discover topology.
- Match display profiles.
- Read brightness through a non-mutating path when possible.
- Adopt observed hardware brightness as desired and presented state for the live session.
- Establish the observation as the confirmed continuity target.
- Do not write merely because a saved value differs.
- Do not replace the persisted user-committed desired value merely because hardware was adopted.
- If observation is unavailable, the saved value for the selected domain may seed presented and desired state, but remains unconfirmed and is not a continuity target.
- A saved seed alone is not a safe baseline for a relative keyboard increment.
- The first explicit absolute user command establishes write capability through the serialized first-write gate.

### First connection

A display with no matched profile follows cold-launch behavior. MyMonitor must not change it merely because it appeared.

### Wake in the same process

- Invalidate pre-sleep services and operations immediately.
- Preserve desired state, the confirmed continuity target, the continuity/wake epoch, and its restore-consumed state separately.
- Wait for a stable topology and reacquire capability.
- Read hardware when possible.
- If the monitor retained the confirmed continuity target within tolerance, publish it as observed.
- If the monitor reset and MyMonitor had a strong identity match plus a confirmed continuity target before sleep, restore that target once through the same control domain and compatible resource semantics.
- The one-restore budget belongs to the session’s continuity/wake epoch, not to an engine generation. Repeated wake or topology generations inside the same epoch do not replenish it.
- Do not automatically apply a newer failed, provisional, or unverified desired value.
- Keep such newer intent visible and require explicit Retry or a new user action to attempt it.
- Never run an unbounded restore loop.
- Gamma and Shade state may be reapplied only after ownership, topology, and continuity are re-established.

### Transient reconnect

A display that disappears and returns inside one topology/wake continuity epoch may restore the confirmed continuity target when its epoch restore budget remains unused. The engine must prove identity and process continuity before restoring.

A display that reconnects without continuity evidence follows first-connection/cold-launch adoption rather than automatically receiving an old saved value.

A newer failed or unverified desired value may survive as intent, but reconnect does not silently turn it into a write.

### Relative adjustments

A relative command such as a brightness hotkey requires a process-local adjustment baseline. Valid baselines are:

- a current observed value;
- the confirmed continuity target for the active domain; or
- an absolute value explicitly chosen by the user in the current process.

A persisted seed that has not been observed or explicitly re-established in the current process is insufficient. The engine first attempts one non-mutating refresh; if no baseline becomes available, it performs no write and returns an actionable `baselineUnavailableForRelativeAdjustment` failure. An absolute slider selection remains allowed and enters the first-write validation gate.

### User Retry

Retry means:

- invalidate stale capability evidence;
- reacquire the selected method;
- preserve desired state;
- explicitly authorize another attempt to converge to the current desired value;
- attempt convergence only after a method is successfully installed;
- publish the reason and outcome in diagnostics.

### Method change

Changing the requested method is explicit permission to transition control inside the selected method family. It is not permission to replay a normalized value from another control domain.

Rules:

1. Hardware-to-hardware transitions may carry a confirmed hardware-domain target between Apple Native and DDC after the new method establishes compatible observation/range semantics.
2. Gamma and Shade use their own saved domain values; a hardware-domain value is never copied into them merely because the number is also normalized `0...1`.
3. An automatic cross-domain fallback starts the new software domain at its neutral state unless a separately qualified transition policy exists.
4. At most one MyMonitor-owned software attenuation domain is non-neutral at a time.
5. The engine acquires rollback evidence, neutralizes/releases conflicting software ownership in the safe order, installs the new owner, and publishes active state only after the transaction succeeds.
6. Failure leaves either the prior method active or an explicit recovering/unavailable state; silent double-dimming and half-transitions are prohibited.

### Profile/range change

Tightening a range is explicit permission to clamp and apply the current desired value if it lies outside the new range.

Changing metadata that does not affect control must not trigger a hardware write.

## 6. Persistence semantics

Persist:

- durable display profile identity;
- user-visible display name override when one exists;
- desired brightness per control domain after a committed user action;
- allowed range;
- requested control preference;
- last known active method as diagnostic evidence, not capability truth;
- identity match evidence needed for migration and duplicate handling.

Do not persist as truth:

- current runtime display ID;
- current IOAV service;
- observed brightness without a timestamp/source;
- a process-local continuity token, epoch, restore budget, or continuity target;
- a capability result as permanently valid;
- an in-flight operation;
- raw diagnostic events without retention limits.

A committed desired value may survive restart, but cold launch still adopts readable hardware state rather than writing the saved value. Hardware adoption updates the live session and process-local continuity target; it does not silently rewrite the persisted user preference.

## 7. Control preference semantics

User-facing choices remain:

- **Automatic**
- **Hardware control**
- **Software control**
- **Display shade**

Internal methods are more specific:

- Apple Native
- DDC/CI
- Gamma
- Shade

Resolution policy:

### Automatic

Try safe methods in this order:

1. Apple Native
2. DDC/CI
3. Gamma
4. Shade

### Hardware control

Try:

1. Apple Native
2. DDC/CI

If neither hardware path is available, report unavailable and offer Automatic or Software control. Do not cross into Gamma or Shade behind an explicit Hardware selection.

### Software control

Try:

1. Gamma when safe
2. Shade

If neither software path is available, report unavailable and offer Automatic or Hardware control. Do not cross into Apple Native or DDC behind an explicit Software selection.

The interface shows requested and active method whenever Automatic selected a fallback or a method is recovering.

### Display shade

Use Shade only. If a Shade window cannot map to the display, report unavailable rather than silently using another method.

## 8. Fallback safety

Automatic capability selection may choose a fallback inside its allowed order. An explicit method-family selection never crosses families. An uncertain write may not trigger any fallback inline.

Example:

1. A DDC write times out.
2. The monitor may have applied the value despite the timeout.
3. Immediately adding Gamma or Shade could double-dim the display.

Therefore:

- one write failure triggers bounded same-method recovery;
- repeated failure marks the session degraded;
- the engine may reprobe through a new generation;
- a method transition occurs only after old ownership and uncertain state are reconciled;
- the frontend receives an actionable failure instead of a silent method switch.

## 9. Empty, detecting, degraded, and failed behavior

### No external displays

The engine exposes a stable empty state. It owns no DDC service, Gamma table, or Shade window.

### Detecting with cached sessions

Connected sessions that remain valid stay usable while slow capability work runs. Their state is marked as cached/recovering rather than replaced with an empty spinner.

### Degraded

At least one display remains usable, but one or more sessions have a typed failure, uncertain observed value, fallback, or recovery in progress.

### Failed

A top-level failure is reserved for cases where topology or engine initialization cannot produce any meaningful display state. Per-display control failures remain per-display.

## 10. Multi-display semantics

- Extended displays are independently controlled.
- A true full mirror may present one logical row if one command is intended to affect the whole external mirror set.
- A partial mirror retains unrelated extended displays.
- A collapsed row fans out through a logical group operation, with each member applying its own range and method.
- One member failure does not falsely mark every member successful.
- Two logical displays that share one physical DDC control require a shared physical-resource model; they must not race independent writes.

## 11. Feedback and error semantics

Errors are truthful but concise.

The presentation layer needs:

- whether the display is connected;
- requested method;
- active method;
- desired brightness;
- observed brightness when known;
- write status;
- health state;
- whether Retry is appropriate;
- a privacy-safe support ID.

Private symbols, service handles, serial numbers, raw EDID, and IORegistry paths remain internal.

## 12. Privacy contract

The backend:

- performs no network request;
- uses no analytics or crash-reporting SDK;
- does not inspect window titles, clipboard data, documents, accounts, or unrelated devices;
- stores display profiles locally;
- emits bounded local diagnostics;
- exports diagnostics only after explicit user action;
- hashes or replaces sensitive identity fields in exported reports.

## 13. Performance contract

- Menu-bar interaction never waits synchronously for display hardware.
- No DDC sleep, read, write, match, or retry occurs on the main actor.
- A slider update changes presented state within the same main-actor turn.
- Intermediate hardware writes are coalesced.
- Topology invalidation is immediate; expensive rediscovery may settle/debounce.
- One broken monitor must not permanently block all displays.
- Teardown must complete without waiting indefinitely for hardware.

## 14. Safety contract

- Never intentionally write a value outside the monitor’s confirmed or configured range.
- Never assume DDC maximum is 100 after a valid range has been read.
- Never write a monitor-off or power VCP command as part of brightness control.
- Do not probe Gamma by visibly altering the display.
- Preserve or restore the baseline transfer table owned before MyMonitor.
- Do not leave a fully black display without a deterministic recovery path.
- The default minimum may be zero, but Settings and diagnostics must make a custom safety minimum possible.
- Teardown removes Shade windows and releases Gamma ownership even during application termination.

## 15. Release promise

MyMonitor may claim support only for behavior exercised by the current release matrix.

Acceptable wording:

- “Uses hardware control when supported by the display and connection.”
- “Falls back to software dimming or a display shade.”

Unacceptable without evidence:

- “Works with every monitor.”
- “All docks support DDC.”
- “Brightness is always restored after wake.”
- “Gamma is safe with every HDR configuration.”
- “The app reads the physical backlight state through every method.”
