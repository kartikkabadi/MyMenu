# Backend Lifecycle and State Machines

This document defines topology capture, engine/session states, operation sequencing, wake/reconnect continuity, fallback, and teardown.

## 1. Why lifecycle is a first-class product concern

External-display control is not a simple property setter. The same physical monitor may:

- disappear and reappear during one dock event;
- receive a new runtime display ID;
- expose a stale IOAV handle after wake;
- enter or leave a mirror set without changing the online ID set;
- reset hardware brightness while the app remains alive;
- temporarily reject DDC while the display firmware wakes;
- lose an AppKit screen mapping during a Space transition;
- share one physical control with multiple logical displays.

Every asynchronous result must therefore be interpreted in the context that produced it.

## 2. Time and identity domains

The engine uses five independent monotonic identities.

### Engine generation

Changes whenever topology or global lifecycle invalidates the current world view.

### Session generation

Changes whenever one persistent display target receives a new runtime mapping, control method, or continuity boundary.

### Operation ID

Identifies one read, write, verification, or recovery transaction.

### Continuity/wake epoch

Identifies one process-local continuity boundary and owns the one-time automatic-restore budget. Several engine generations may occur inside one epoch.

### Physical resource ID

Identifies the underlying Apple-native service, IOAV service, Gamma target, Shade window, or shared physical control.

A completion is accepted only if all relevant identities still match.

## 3. Immutable topology snapshot

A generation resolves from one immutable snapshot:

```swift
struct DisplayTopologySnapshot: Equatable, Sendable {
  let generation: UInt64
  let capturedAt: ContinuousClock.Instant
  let reason: ReconfigurationReason
  let runtimeDisplays: [RuntimeDisplay]
  let mirrorSets: [MirrorSet]
  let screenMappings: [ScreenMapping]
  let connectionEvidence: [RuntimeDisplayID: ConnectionEvidence]
  let signature: TopologySignature
}
```

The snapshot includes enough evidence to answer:

- which displays are online;
- which are built in versus external;
- which runtime IDs map to AppKit screens;
- which displays belong to mirror sets;
- whether the topology is a true full mirror or partial mirror;
- which connection/IORegistry evidence belongs to each display;
- whether two logical displays may share one physical control.

No control resolution for a generation performs a fresh live topology query behind the snapshot.

## 4. Topology events and settle policy

Events may come from:

- `CGDisplayRegisterReconfigurationCallback`;
- `NSApplication.didChangeScreenParametersNotification`;
- `NSWorkspace.didWakeNotification`;
- active Space changes for Shade layout only;
- explicit Retry or method/profile changes.

### Immediate work

On a topology-invalidating event:

1. increment engine generation;
2. cancel scheduled settle work;
3. invalidate publishability of all old operations;
4. stop temporary mirror/Space holds;
5. remove resources proven disconnected;
6. publish cached/recovering state;
7. record the event.

### Settled work

Expensive discovery runs after the topology has been quiet for a short interval.

The settle algorithm must be testable and bounded:

```text
first event
  → invalidate immediately
  → wait 150 ms
  → if another event arrives, restart quiet timer
  → capture after 150 ms quiet
  → never defer longer than 1.5 s from first event
```

Exact durations require hardware evidence. The contract requires a quiet window and maximum deadline rather than a fixed unexplained 600 ms delay.

## 5. Engine state machine

```swift
enum MonitorEngineState: Equatable, Sendable {
  case idle
  case discovering(DiscoveryState)
  case ready([DisplaySessionSnapshot])
  case degraded(DegradedEngineState)
  case empty
  case failed(EngineFailure)
  case tearingDown
  case terminated
}
```

### `idle`

Constructed but not started. No callbacks or hardware resources are owned.

### `discovering`

A topology generation is being captured, identities matched, or capabilities acquired.

It includes cached sessions when available:

```swift
struct DiscoveryState {
  let reason: ReconfigurationReason
  let generation: UInt64
  let cachedSessions: [DisplaySessionSnapshot]
  let startedAt: ContinuousClock.Instant
}
```

### `ready`

All connected logical targets have an installed usable method or a truthful per-display unavailable state with no engine-wide fault.

### `degraded`

At least one target is usable, but one or more sessions are recovering, using fallback, uncertain, or failed.

### `empty`

No external targets exist. No method resources remain installed.

### `failed`

The engine could not capture or interpret topology well enough to expose meaningful display state.

### `tearingDown` / `terminated`

Terminal boundary. No new event, timer, or completion may start discovery or publish session state.

## 6. Session state machine

```swift
enum DisplaySessionHealth: Equatable, Sendable {
  case discovering
  case available
  case recovering(RecoveryReason)
  case degraded(ControlFailure)
  case unavailable(ControlFailure)
  case disconnected
  case releasing
}
```

A session snapshot may remain visible during `recovering` if its persistent identity and cached state are still valid.

## 7. Capability acquisition

Capability acquisition is staged.

### Stage 1 — topology and identity

No brightness write.

### Stage 2 — non-mutating evidence

- Apple Native: query capability/read if available.
- DDC: discover candidate service and read VCP `0x10`.
- Gamma: determine safety context and whether a baseline table can be captured; do not alter it.
- Shade: verify AppKit screen mapping and window eligibility; do not show it.

### Stage 3 — resolution

The resolver orders candidates and identifies whether the selected candidate requires first-write validation.

### Stage 4 — installation

Install ownership and publish method state without applying a saved value unless lifecycle policy permits it.

### Stage 5 — explicit write validation

A method that cannot prove write capability without a write validates through one serialized first-write gate per physical resource. During a drag, presentation and desired state continue updating, but only the latest eligible value enters validation. At most one validation operation and one newest catch-up/final operation may survive. Failure cancels pending transport work and leaves the session degraded; it never emits a storm of unvalidated writes.

## 8. Brightness operation state machine

```swift
enum BrightnessOperationPhase {
  case queued
  case preparing
  case writing(attempt: Int)
  case waitingForVerification
  case acceptedUnverified
  case applied(observed: Double)
  case failed(ControlFailure)
  case superseded
  case cancelled
}
```

### Direct manipulation

1. UI begins adjustment.
2. Presented brightness updates immediately.
3. Engine updates the active domain’s transient desired value.
4. If write capability is validated, the method coalesces eligible writes.
5. If validation is required, one latest-value validation operation owns the resource while newer desired values replace the pending catch-up target.
6. Old intermediate operations become superseded.
7. UI ends adjustment and commits the final desired value for the active domain.
8. The method performs at most the current validation plus one newest final/catch-up operation.
9. Observed state updates only from evidence; transport acceptance alone publishes `acceptedUnverified`.
10. Persistence records the committed domain value regardless of immediate verification, plus failure state when relevant.

### Operation ordering

For one physical resource:

- operation sequence numbers strictly increase;
- only the newest pending value may start after coalescing;
- a started older write may finish, but cannot publish over a newer operation;
- verification applies only to the operation it verifies;
- teardown invalidates all operation publication.

## 9. Verification policy

### Apple Native

- Treat a successful setter without trustworthy readback as `acceptedUnverified`, not applied.
- Read back when the API supports reliable readback without material delay.
- Publish `applied(observed:)` only from trustworthy evidence.
- If readback differs beyond tolerance, report verification mismatch.

### DDC

During drag:

- coalesce writes;
- do not read back every intermediate value.

On committed final value:

- write once through the active service;
- wait a bounded monitor-settle interval;
- read VCP `0x10` when the monitor supports reliable reads;
- accept within tolerance;
- retry/rematch once for a stale-service class failure;
- never loop indefinitely.

A hardware-qualified write-only display may remain usable when transport calls are accepted but reads are unreliable. Such operations remain `acceptedUnverified`; they never create observed brightness or a confirmed continuity target. Runtime inference must not promote unobservable writes to applied merely because no error was returned.

### Gamma and Shade

These are locally owned deterministic methods. A successful per-display table/window application can immediately publish observed state, subject to owner and generation checks.

## 10. Cold launch transition

```text
idle
 → discovering(coldLaunch)
 → capture topology
 → migrate/match profiles
 → gather non-mutating capability evidence
 → install sessions
 → adopt readable observed brightness
 → ready/degraded/empty
```

Prohibited during this path:

- no-op DDC write for capability validation;
- saved-brightness restore;
- Gamma probe multiplier;
- visible Shade;
- unbounded wait for one monitor.

When hardware brightness is unreadable, the selected domain may be seeded from a profile and marked unconfirmed. Relative commands first require a process-local baseline; an explicit absolute selection may enter the first-write validation gate.

## 11. Wake transition

```text
wake callback
 → increment generation immediately
 → mark hardware sessions recovering
 → invalidate IOAV services and old operations
 → preserve the continuity/wake epoch, confirmed continuity target, and desired state separately
 → settle topology
 → reacquire identity and methods
 → observe hardware when possible
 → restore the confirmed continuity target only when the epoch restore budget is unused
 → ready/degraded
```

Rules:

- a pre-sleep completion cannot install after wake;
- no write occurs during the quiet/settle interval;
- one bounded restore is allowed per session/continuity epoch and only through the continuity target’s compatible control domain; engine generations only guard publication;
- repeated wake or topology generations inside the same continuity epoch do not replenish restore eligibility;
- if identity confidence drops, adopt rather than restore;
- if verification is uncertain, report degraded rather than repeatedly writing;
- Gamma baseline must be recaptured after wake before reapplication;
- Shade windows must remap to current screens before ordering front.

## 12. Disconnect and reconnect

### Immediate disconnect

- remove the runtime member from the topology;
- stop writes to its physical resource;
- release resources no longer shared;
- preserve the profile;
- mark the session disconnected if Settings needs remembered state;
- remove it from the frequent control surface.

### Transient reconnect

Continuity requires:

- reconnect inside the same continuity window;
- high-confidence persistent identity match;
- compatible physical resource or connection evidence;
- no intervening cold process launch.

Only then may the confirmed continuity target carry forward automatically. A newer failed, provisional, or unverified desired value remains intent only and requires explicit Retry or a new user action.

### Ordinary reconnect

Without continuity, observe/adopt first. Do not surprise the user with an old profile write.

## 13. Mirroring and grouping

A `MirrorSet` is explicit topology data, not inferred ad hoc in multiple methods.

```swift
struct MirrorSet: Equatable, Sendable {
  let id: MirrorSetID
  let members: [RuntimeDisplayID]
  let representative: RuntimeDisplayID
  let isFullDesktopMirror: Bool
}
```

### Full mirror

The frontend may display one logical target. The session owns a group of member sessions/resources.

A group write returns per-member results:

```swift
struct GroupWriteReceipt {
  let requested: Double
  let members: [PersistentDisplayID: Result<ControlWriteReceipt, ControlFailure>]
}
```

The group is not marked fully applied unless every required member succeeds.

### Partial mirror

Unrelated extended displays remain visible and independently controlled.

### Shared physical backlight

If two logical displays map to one DDC service, they must share one resource/session. The UI may show two logical rows only if product behavior can explain synchronized observed state. B1-B6 should initially collapse or mark the duplicate rather than race two writes.

## 14. Method and domain transition

```text
current method/domain A
 → resolve inside the requested family
 → acquire candidate B in neutral state
 → validate generation/resource/rollback evidence
 → same domain: transfer only a confirmed compatible target
 → cross domain: select B-domain state; never replay A-domain numeric intent
 → neutralize conflicting software owner
 → install and publish B
 → release A without allowing stale teardown
```

Rules:

- Apple Native ↔ DDC may transfer a confirmed hardware-domain target after compatible range/observation is established.
- Hardware ↔ Gamma/Shade does not copy normalized values across domains.
- Gamma and Shade are never simultaneously non-neutral except a narrowly scoped, documented transition hold.
- Automatic cross-domain fallback starts neutral unless a separately qualified bridge exists.
- Explicit Software selection may apply that software domain’s own saved value after safe installation.
- If B acquisition fails before ownership, A remains active.
- If A must be released first, the session becomes recovering and records rollback context. Silent half-transition or double-dimming is prohibited.

## 15. DDC failure recovery

Typed failure classes drive bounded behavior.

### Stale service / not found

- clear service;
- rediscover once;
- retry newest operation once.

### Timeout / checksum / read failure

- keep desired state;
- do not update observed;
- retry according to the operation’s bounded policy;
- mark degraded after exhaustion.

### Write rejected

- do not silently install Gamma or Shade;
- mark hardware method degraded;
- offer Retry or explicit method change;
- automatic resolver may transition only through a new generation.

### Verification mismatch

- publish the actual observed value if reliable;
- preserve desired value;
- mark degraded;
- do not continuously fight the monitor.

## 16. Gamma lifecycle

```text
candidate
 → capture baseline table
 → verify safety context
 → install owner
 → compose/apply desired table
 → on topology/profile/HDR change: suspend and recapture
 → on release: restore captured baseline if still current owner
```

A global ColorSync restore is a last-resort recovery, not the normal per-display release path.

## 17. Shade lifecycle

```text
candidate
 → map runtime display to NSScreen
 → construct hidden owned panel
 → apply desired alpha
 → order front only when dimming is nonzero and mapping is valid
 → remap after topology/Space changes
 → order out/close on release
```

A stale animation completion cannot hide or show a newer state.

## 18. App termination

Application termination calls a synchronous idempotent coordinator boundary on the main actor. It does not await ordinary asynchronous method teardown or private hardware I/O.

Required order:

1. enter `tearingDown`;
2. unregister display and notification callbacks;
3. cancel settle/transition timers;
4. invalidate operation publication;
5. stop DDC actors from accepting new work;
6. close Shade windows;
7. restore owned Gamma baselines;
8. clear session owners;
9. enter `terminated`.

The engine does not rely on an asynchronously scheduled termination notification to restore system state.

## 19. Invariants enforced by tests

- no old generation publishes after a new topology event;
- wake invalidates before any debounce;
- disconnect releases resources before rediscovery;
- cold launch performs no brightness write;
- a failed write does not update observed state;
- a newer operation wins over older verification;
- fallback does not occur inside an uncertain write;
- teardown is idempotent;
- callbacks after teardown do nothing;
- full mirror fan-out reports per-member results;
- partial mirror retains unrelated displays;
- reconnect restore requires continuity and high-confidence identity;
- repeated callback generations inside one wake/continuity epoch produce exactly one same-domain restore attempt;
- an unconfirmed saved seed cannot drive a relative adjustment;
- first-write validation permits at most one validation plus one newest catch-up operation;
- accepted-unverified does not update observed or continuity state;
- cross-domain transitions do not replay numeric desired state or double-dim;
- terminal teardown restores main-thread-owned state without awaiting hardware actors;
- Gamma release affects only the active owner;
- Shade animation completion is generation-guarded.
