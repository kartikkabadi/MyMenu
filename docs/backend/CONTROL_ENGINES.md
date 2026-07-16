# Control Engine Contracts

This document defines the four internal brightness methods, their capability evidence, lifecycle, read/write semantics, safety rules, and fallback order.

## 1. Internal methods versus user-facing choices

User-facing Settings remain simple:

- Automatic
- Hardware control
- Software control
- Display shade

Internal methods are:

```swift
enum DisplayControlMethod: String, Codable, Sendable {
  case appleNative
  case ddc
  case gamma
  case shade
}

enum BrightnessControlDomain: String, Codable, Sendable {
  case hardware
  case gamma
  case shade
}
```

Apple Native and DDC share the hardware domain. Gamma and Shade are separate attenuation domains. Numeric intent is not copied automatically across domains.

Diagnostics may name the internal method. The primary popover should not expose private implementation vocabulary unless needed to explain a failure.

## 2. Candidate order

### Automatic

1. Apple Native
2. DDC/CI
3. Gamma when safe
4. Shade

### Hardware control

1. Apple Native
2. DDC/CI
3. unavailable with an explicit suggestion to choose Automatic or Software control

### Software control

1. Gamma when safe
2. Shade
3. unavailable with an explicit suggestion to choose Automatic or Hardware control

### Display shade

1. Shade only

A candidate is selected from current evidence. A historical last method is a hint, never capability truth.

---

# 3. Apple Native engine

## 3.1 Purpose

Apple Native represents macOS-controlled backlight paths exposed through DisplayServices/CoreDisplay behavior for compatible Apple and natively integrated displays.

It is distinct from generic DDC even when both are “hardware control” to the user.

## 3.2 Private boundary

All private symbols are declared and invoked only in `PrivateDisplayKit`.

Potential adapter functions include:

- capability query;
- brightness read;
- brightness write;
- linear brightness read/write where required for full-scale consistency.

The engine does not link private symbol names into policy, presentation, or test modules.

## 3.3 Capability evidence

Preferred evidence order:

1. explicit capability function where available;
2. successful non-mutating read with a sane normalized value;
3. known Apple display classification as weak supporting evidence;
4. first user-initiated write and readback validation.

Do not alter brightness by ±0.01 during cold-launch capability discovery.

Capability states:

- available/readable;
- available but write unvalidated;
- available and write-validated;
- unavailable;
- symbol unavailable on this OS;
- degraded after write/readback failure.

## 3.4 Read contract

- return normalized `0...1`;
- reject NaN/infinite/out-of-range values;
- include source and timestamp;
- never block the main actor;
- map unknown/private return codes to typed failure;
- do not assume one successful historical read remains valid after wake/topology change.

## 3.5 Write contract

- clamp to configured range before transport conversion;
- call the native setter once per eligible operation;
- record the private return code internally;
- perform bounded readback when reliable;
- treat a successful setter with unavailable readback as `acceptedUnverified`, which does not create observed or continuity state;
- no unbounded smoothing loop;
- operation IDs and generations guard completion.

## 3.6 Smooth transitions

The first Apple Native implementation uses instant writes for slider tracking and optional system/native smoothing only if:

- it is cancelable or generation-guarded;
- a newer desired value supersedes it;
- final committed state can be verified;
- it does not block other displays.

Custom frame-by-frame smoothing is not required for B3.

## 3.7 Failure behavior

- one stale/unavailable failure invalidates capability for the current generation;
- automatic mode may begin a new resolution generation;
- do not silently combine Native and Gamma/ Shade on one uncertain operation;
- restore no state at teardown: Apple Native owns no persistent software dimming resource.

---

# 4. DDC/CI engine

## 4.1 Scope

The first DDC engine controls only VCP code `0x10` luminance.

Explicitly out of scope:

- contrast;
- audio volume/mute;
- input source;
- power mode;
- RGB gain;
- capability-driven UI for unrelated VCP codes.

## 4.2 Layering

```text
DDCSession
  desired/observed/health policy
        │
        ▼
DDCTransportLane actor
  operation ordering, coalescing, retry, verification
        │
        ▼
IOAVTransport adapter
  service handle + I2C packet calls
        │
        ▼
PrivateDisplayKit / IORegistry matcher
```

`DisplayRouter`/`MonitorEngine` never calls `Arm64DDC` or IOAV directly.

## 4.3 Service candidate

```swift
struct DDCServiceCandidate: Sendable {
  let serviceID: DDCServiceID
  let resourceID: PhysicalControlResourceID
  let runtimeDisplayCandidates: [RuntimeDisplayID]
  let connectionEvidence: ConnectionEvidence
  let matchEvidence: [ServiceMatchEvidence]
  let score: Int
  let discouraged: Bool
  let dummy: Bool
}
```

Raw handles remain inside the adapter/actor. A candidate exposed to policy uses stable internal IDs.

## 4.4 Matching rules

- perform global assignment across displays and services;
- one service cannot be assigned to two independent writers;
- one display cannot receive two active services;
- ignore dummy/known-bad candidates through data-driven rules, not scattered model checks;
- record why the winning candidate beat alternatives;
- ambiguous equal-scoring assignment is not silently accepted;
- connection location is strong evidence but must not override contradictory serial/EDID evidence;
- service matching is invalidated by wake and topology signature changes.

The existing greedy score implementation is retained only until a tested global assignment policy replaces it.

## 4.5 DDC value model

```swift
struct DDCValue: Equatable, Sendable {
  let current: UInt16
  let maximum: UInt16
}
```

Validation:

- maximum must be greater than zero;
- current greater than maximum is clamped only for presentation and recorded as malformed evidence;
- an absurd or changing maximum is a typed range failure;
- normalized brightness is `current / maximum`;
- configured user range applies after normalization;
- never assume maximum 100 after a successful read.

## 4.6 Discovery policy

Cold discovery is read-only:

1. discover candidate service;
2. read VCP `0x10`;
3. validate checksum/range;
4. publish readable capability;
5. mark write capability unvalidated.

Do not write the current value merely to prove the write path during cold launch.

The first explicit absolute user write enters one serialized validation gate. Relative commands require a process-local adjustment baseline before this gate can be used.

## 4.7 Write coalescing

The transport lane maintains:

- newest desired normalized value;
- operation sequence;
- scheduled flush;
- current attempt;
- invalidation state.

During slider tracking:

- update the active domain’s desired value immediately;
- coalesce intermediate writes over a short evidence-backed interval;
- do not queue every pointer event;
- never execute a superseded queued write;
- when write capability is unvalidated, allow one latest-value validation operation and retain at most one newest catch-up/final target;
- if validation fails, cancel the pending catch-up and publish a typed failure.

On slider release:

- schedule or execute the final committed value promptly;
- ensure the final operation supersedes an older debounce;
- persist desired independently of transport completion;
- verify according to the final-write policy.

The current 90 ms interval is a tested baseline, not a permanent magic constant. It becomes an injectable policy value.

## 4.8 Packet timing and retries

DDC firmware may need write delay, read delay, multiple cycles, and retry delay.

The default policy is bounded:

```swift
struct DDCTimingPolicy: Equatable, Sendable {
  let preWriteDelay: Duration
  let writeCycles: Int
  let readDelay: Duration
  let attempts: Int
  let retryDelay: Duration
  let verificationDelay: Duration
}
```

Rules:

- no `usleep` outside the transport adapter;
- no unbounded attempt count;
- retry policy is attached to failure class;
- defaults are conservative;
- per-display adaptive timing is future work and must be learned from evidence, not exposed as a settings dump;
- one monitor’s delays must not block the main actor.

## 4.9 Write and verification

Final write flow:

1. validate current operation/generation;
2. resolve active service;
3. ensure a valid maximum, reading if needed;
4. convert normalized desired to DDC value;
5. skip only when the engine has reliable evidence the exact value is already applied;
6. write;
7. if write reports failure, discard service and rematch once for stale-service failures;
8. after success, wait bounded verification delay;
9. read back when supported;
10. accept within tolerance or report mismatch.

Tolerance is monitor-value-based, defaulting to the larger of:

- 2 DDC units;
- 1% of maximum.

A monitor may use a documented write-only compatibility mode only when physical qualification establishes that transport acceptance is useful despite unreliable reads. Runtime operations in this mode remain `acceptedUnverified`; they never synthesize observed state or continuity evidence.

## 4.10 Typed DDC failures

```swift
enum DDCFailure: Equatable, Sendable {
  case noService
  case ambiguousServiceMatch
  case discouragedService
  case dummyService
  case readTimeout
  case writeTimeout
  case invalidChecksum
  case invalidRange(current: UInt16, maximum: UInt16)
  case writeRejected(code: Int32?)
  case verificationMismatch(requested: UInt16, observed: UInt16)
  case staleService
  case topologyChanged
  case superseded
  case cancelled
  case unsupportedArchitecture
  case privateSymbolUnavailable
}
```

The actual shared `ControlFailure` may wrap these values.

## 4.11 Recovery

- stale service: rematch once and retry newest operation;
- invalid checksum/read timeout: bounded retry, then degraded;
- write rejection: no automatic double-dimming fallback inside the operation;
- topology change: cancel publication and let the new generation resolve;
- wake: invalidate all service handles immediately;
- repeated failure: publish degraded/unavailable with Retry.

## 4.12 Resource release

- invalidate pending writes;
- increment lane operation generation;
- release/clear private service handle;
- reject late completion;
- remove lane when no session owns its resource;
- balance every IORegistry iterator/object allocation.

---

# 5. Gamma engine

## 5.1 Product meaning

Gamma changes the software transfer function. It does not change the monitor’s physical backlight. The frontend labels it **Software control**.

## 5.2 Eligibility

Gamma is eligible only when:

- target is external;
- a per-display transfer table can be captured;
- the engine can install and restore under exclusive ownership;
- the current display mode is not known unsafe;
- the display is not a virtual/dummy target unless explicitly qualified;
- full mirroring and HDR/EDR policy allow it;
- user preference permits it.

## 5.3 No destructive probe

Prohibited capability test:

- temporarily dim the screen;
- read the dimmed value;
- restore globally.

Instead:

1. query/capture the current transfer table;
2. validate sample count and monotonicity;
3. record baseline ownership evidence;
4. defer actual mutation until an explicit user write or wake restore.

## 5.4 Baseline table

```swift
struct GammaTable: Equatable, Sendable {
  let red: [CGGammaValue]
  let green: [CGGammaValue]
  let blue: [CGGammaValue]
  let sampleCount: UInt32
  let capturedAt: ContinuousClock.Instant
  let topologySignature: TopologySignature
}
```

Requirements:

- preserve the complete captured baseline;
- compose dimming by scaling/interpolating the baseline, not replacing it with a generic linear curve;
- never persist raw tables across process launches as current truth;
- recapture after wake, color-mode change, topology change, or ownership loss;
- restore the captured baseline per display on teardown when still the owner.

## 5.5 Composition

For normalized brightness `b`, apply a minimum-safe multiplier `m(b)` to every baseline sample while preserving channel relationships and monotonicity.

Initial policy may retain the current `0.15...1.0` lower bound, but it becomes a named/tested policy and must not destroy the baseline curve.

Zero software brightness may map to the configured minimum rather than mathematically zero to avoid a black-screen trap. Shade can provide deeper visual dimming.

## 5.6 HDR/EDR safety

Gamma defaults to unavailable when:

- HDR/EDR is active and baseline behavior is not qualified;
- transfer-table APIs return unusable values;
- another system component appears to replace the table repeatedly;
- a full mirror includes a built-in HDR display and ownership cannot be isolated;
- restore cannot be proven.

When unsafe, Automatic chooses Shade. The engine does not fight HDR or continuously reapply Gamma.

## 5.7 Ownership

One owner token per runtime display.

- replacement installs a new owner before old teardown where safe;
- stale owner teardown does nothing;
- temporary mirror/Space holds use the same ownership registry or a distinct composed layer with deterministic precedence;
- normal release restores the captured per-display baseline;
- global `CGDisplayRestoreColorSyncSettings()` is emergency recovery only, followed by replay of remaining owners.

## 5.8 Observed state

Gamma is locally deterministic. After a successful table installation under the current owner, observed software brightness equals desired software brightness.

This is not a claim about physical luminance.

---

# 6. Shade engine

## 6.1 Product meaning

Shade overlays translucent black on one display. It does not change the backlight or color transfer function. It is the safest universal visual fallback when an AppKit screen mapping exists.

## 6.2 Eligibility

- external runtime display;
- valid `NSScreen` mapping;
- not a headless/virtual target without an actual visible screen;
- window can join the required Spaces/fullscreen context;
- user preference permits Shade or safer methods are unavailable.

## 6.3 Window contract

The Shade window is:

- borderless;
- nonactivating;
- mouse-transparent;
- excluded from window cycling;
- Space/fullscreen aware;
- owned by one Shade session;
- hidden at brightness 1;
- closed on teardown;
- generation-guarded for animation completion.

Its level must be high enough to dim normal content but must not block system-critical UI unexpectedly. Level changes require manual qualification.

## 6.4 Brightness mapping

```text
shadeAlpha = 1 - normalizedBrightness
```

The allowed range is applied before alpha conversion.

A minimum visible luminance safeguard may cap alpha below complete opacity unless the user explicitly configures zero. Recovery remains available through keyboard and Settings.

## 6.5 Spaces and topology

- layout-only events remap/reaffirm Shade without reprobe;
- topology-invalidating events suspend and remap through a new generation;
- a stale Space animation cannot order out a newer dim state;
- full mirror group behavior is explicit and tested;
- temporary Gamma holds used to mask Space transitions remain separate from permanent Gamma control and are always released.

## 6.6 Screen capture behavior

The backend specification does not yet bind whether Shade should appear in screenshots/screen sharing. B10 must test `NSWindow.SharingType` behavior and record the decision in `DECISIONS.md`.

The default must avoid exposing hidden content or producing inconsistent local-versus-shared brightness without documentation.

## 6.7 Observed state

After the current owner applies window alpha and ordering, observed Shade brightness equals desired Shade brightness.

If the screen mapping disappears, observed state becomes unavailable/recovering rather than remaining falsely applied.

---

# 7. Cross-method rules

## 7.1 Initial state

- Apple Native and DDC prefer readable observed hardware state.
- Gamma and Shade start at identity/no-dim until lifecycle policy permits applying desired state.
- cold launch does not apply saved dimming automatically.

## 7.2 Method and domain switches

- preserve desired state separately for hardware, Gamma, and Shade domains;
- transfer a value automatically only inside compatible same-domain semantics;
- never copy a hardware normalized value into Gamma or Shade, or vice versa;
- acquire the new owner in neutral state and retain rollback evidence;
- automatic cross-domain fallback starts neutral unless a qualified bridge exists;
- explicit selection may apply the selected domain’s own saved value;
- neutralize/release conflicting software attenuation before another software domain becomes non-neutral;
- never let old teardown reset the new owner;
- update active method only after installation succeeds.

## 7.3 Multi-method stacking

MyMonitor owns one active control domain for user intent. The physical backlight necessarily remains present while software attenuation is active, but MyMonitor does not issue simultaneous hardware and software operations to realize one command. Gamma and Shade are never both permanently non-neutral.

Prohibited combinations:

- DDC + Gamma to represent one desired value;
- DDC + Shade after uncertain DDC failure;
- Gamma + Shade except a narrowly documented temporary transition hold;
- two DDC writers for one physical resource.

## 7.4 Method health

```swift
enum ControlHealth: Equatable, Sendable {
  case unknown
  case healthy
  case provisional
  case recovering
  case degraded(ControlFailure)
  case unavailable(ControlFailure)
}
```

Capability and health are generation-scoped.

## 7.5 Diagnostics

Every method records:

- candidate evidence;
- selection/fallback reason;
- resource support ID;
- read/write duration;
- operation result;
- retry/rematch;
- desired/observed delta;
- lifecycle reason;
- teardown outcome.

Raw private handles and identity data never leave the adapter.

## 7.6 Release qualification

A method is not “supported” by code presence. It is supported only for matrix rows that pass `QA_MATRIX.md` on the release candidate.
