# Backend Architecture

This document defines the target modules, ownership rules, protocols, concurrency model, and data flow. It is not permission for a broad rewrite. Each implementation ticket introduces only the seams it needs.

## 1. Architectural goals

The backend must be:

- deterministic at the policy layer;
- testable without a connected display;
- responsive on the main actor;
- explicit about lifecycle reasons;
- explicit about desired versus observed state;
- conservative around private APIs and color state;
- modular enough to replace one transport without replacing the product;
- small enough for one maintainer to understand.

## 2. Target module map

```text
MyMonitor/
├── Engine/
│   ├── MonitorEngine.swift
│   ├── MonitorEngineState.swift
│   ├── DisplayControlSession.swift
│   ├── ControlResolver.swift
│   ├── BrightnessOperation.swift
│   └── EngineClock.swift
├── Topology/
│   ├── DisplayTopologyProvider.swift
│   ├── CoreGraphicsTopologyProvider.swift
│   ├── DisplayTopologySnapshot.swift
│   └── DisplayIdentityResolver.swift
├── Profiles/
│   ├── DisplayProfile.swift
│   ├── DisplayProfileStore.swift
│   ├── UserDefaultsDisplayProfileStore.swift
│   └── LegacyV2Migration.swift
├── Control/
│   ├── DisplayControlMethod.swift
│   ├── AppleNative/
│   ├── DDC/
│   ├── Gamma/
│   └── Shade/
├── PrivateDisplayKit/
│   ├── PrivateSymbols.h
│   ├── DisplayServicesAdapter.swift
│   ├── CoreDisplayAdapter.swift
│   └── IOAVAdapter.swift
├── Diagnostics/
│   ├── EngineEvent.swift
│   ├── DiagnosticRecorder.swift
│   ├── SupportReport.swift
│   └── PrivacyRedactor.swift
├── Presentation/
│   └── DisplayRouterAdapter.swift
└── Policies/
    └── hardware-free value and transition policies
```

Names may change, but the boundaries are binding.

## 3. Core ownership

## 3.1 `MonitorEngine`

`MonitorEngine` is the single authoritative coordinator for connected-display sessions.

It owns:

- current immutable topology snapshot;
- reconfiguration generation;
- connected session map;
- global lifecycle state;
- profile matching results;
- requested method and range changes;
- publication of engine snapshots;
- transition between control methods;
- terminal teardown.

It does not:

- perform DDC I/O directly;
- call private symbols directly;
- own SwiftUI views;
- format user-facing diagnostic prose;
- sleep or block the main actor.

`MonitorEngine` remains `@MainActor` because it publishes state consumed by the UI and coordinates AppKit/Gamma/Shade ownership that is main-thread-sensitive.

## 3.2 `DisplayControlSession`

One session represents one logical display target or one logical group target.

A session owns:

- persistent display identity;
- current runtime members;
- desired brightness values by control domain;
- active control domain;
- observed brightness and source;
- confirmed continuity target and epoch restore budget;
- requested control preference;
- installed control method;
- capability evidence;
- health;
- current brightness operation;
- continuity token;
- last successful write/read timestamps.

A session does not own raw private service matching logic. It receives a method implementation through the resolver.

Suggested model:

```swift
struct DisplaySessionSnapshot: Equatable, Sendable {
  let id: PersistentDisplayID
  let runtimeMembers: [RuntimeDisplayID]
  let name: String
  let connection: ConnectionSummary
  let activeDomain: BrightnessControlDomain
  let desiredBrightness: Double
  let desiredByDomain: DesiredBrightnessSet
  let observedBrightness: ObservedBrightness?
  let confirmedContinuityTarget: ConfirmedContinuityTarget?
  let allowedRange: ClosedRange<Double>
  let requestedPreference: ControlPreference
  let activeMethod: DisplayControlMethod?
  let health: DisplaySessionHealth
  let writeStatus: BrightnessWriteStatus
  let supportID: String
}
```

## 3.3 Control method implementations

Every installed method conforms to an asynchronous contract.

```swift
protocol DisplayControl: AnyObject, Sendable {
  var method: DisplayControlMethod { get }
  var domain: BrightnessControlDomain { get }
  var resourceID: PhysicalControlResourceID { get }

  func readBrightness() async throws -> ControlReading
  func writeBrightness(
    _ normalized: Double,
    operation: BrightnessOperationContext
  ) async throws -> ControlWriteReceipt
  func neutralizeForTransition(
    operation: BrightnessOperationContext
  ) async throws
  func suspend(reason: SuspensionReason) async
  func resume(context: ResumeContext) async throws
  func teardown() async
}
```

Actual actor annotations may differ. Required semantics:

- reads and writes are cancelable or generation-checked;
- a method reports typed failures;
- a method exposes its physical resource identity;
- teardown is idempotent;
- stale completion cannot publish into a replacement session.

## 3.4 `ControlResolver`

The resolver is a pure or mostly pure policy component.

Inputs:

- reconfiguration reason;
- topology snapshot;
- display profile;
- identity confidence;
- control preference;
- capability evidence;
- safety context;
- current installed method and health.

Output:

```swift
struct ControlResolution {
  let orderedCandidates: [ControlCandidate]
  let selected: DisplayControlMethod?
  let fallbackReason: FallbackReason?
  let requiresWriteToValidate: Bool
  let warnings: [ControlWarning]
}
```

The resolver does not perform I/O. A capability coordinator gathers evidence and asks the resolver again.

## 3.5 `DisplayTopologyProvider`

The topology provider converts public and private display evidence into one immutable snapshot.

```swift
protocol DisplayTopologyProviding: Sendable {
  func snapshot(reason: ReconfigurationReason) async throws -> DisplayTopologySnapshot
  func events() -> AsyncStream<DisplayTopologyEvent>
}
```

The production provider may bridge callbacks into an `AsyncStream`; tests provide deterministic event traces.

## 3.6 `DisplayProfileStore`

The profile store owns versioned local preferences and migration.

```swift
protocol DisplayProfileStoring: Sendable {
  func loadSnapshot() async throws -> DisplayProfileSnapshot
  func saveSnapshot(_ snapshot: DisplayProfileSnapshot) async throws
  func migrateLegacyIfNeeded(
    topology: DisplayTopologySnapshot
  ) async throws -> MigrationReport
}
```

The first implementation may store one versioned Codable blob in `UserDefaults`. Callers must not know storage keys.

## 3.7 `DiagnosticRecorder`

The recorder accepts structured events and retains a bounded local history.

```swift
protocol DiagnosticRecording: Sendable {
  func record(_ event: EngineEvent) async
  func snapshot() async -> DiagnosticSnapshot
  func clear() async
}
```

No engine component writes prose logs as its primary evidence. Prose support reports are rendered from structured events.

## 4. Data types

## 4.1 Control-domain state

```swift
enum BrightnessControlDomain: String, Codable, Sendable {
  case hardware
  case gamma
  case shade
}

struct DesiredBrightnessSet: Equatable, Codable, Sendable {
  var hardware: Double?
  var gamma: Double?
  var shade: Double?
}

struct ConfirmedContinuityTarget: Equatable, Sendable {
  let domain: BrightnessControlDomain
  let method: DisplayControlMethod
  let resourceID: PhysicalControlResourceID
  let value: Double
  let evidence: ObservationSource
  let establishedAt: ContinuousClock.Instant
}
```

A value is transferable automatically only inside compatible domain semantics. A control-domain change is a transaction, not a numeric copy.

## 4.2 Runtime versus persistent identity

```swift
struct RuntimeDisplayID: Hashable, Sendable {
  let rawValue: CGDirectDisplayID
}

struct PersistentDisplayID: Hashable, Codable, Sendable {
  let rawValue: String
}
```

Runtime IDs never become persistence keys directly.

## 4.3 Physical control resource

Logical macOS displays and physical brightness controls are not always one-to-one.

```swift
enum PhysicalControlResourceID: Hashable, Sendable {
  case appleNative(String)
  case ioav(String)
  case gamma(RuntimeDisplayID)
  case shade(RuntimeDisplayID)
  case grouped(String)
}
```

The exact associated values are internal stable hashes, not raw pointers.

This resource ID prevents:

- two logical Picture-by-Picture displays racing one backlight;
- two sessions installing Gamma for one runtime display;
- stale teardown affecting a replacement;
- concurrent operations against one IOAV service.

## 4.4 Capability evidence

Capability is not a Boolean.

```swift
struct ControlCapabilityEvidence: Equatable, Sendable {
  let method: DisplayControlMethod
  let state: CapabilityState
  let observedAt: ContinuousClock.Instant
  let topologySignature: TopologySignature
  let source: CapabilitySource
  let confidence: CapabilityConfidence
  let failure: ControlFailure?
}

enum CapabilityState {
  case unknown
  case available
  case unavailable
  case degraded
  case requiresUserWriteValidation
}
```

Evidence expires when topology, wake continuity, or the underlying resource changes.

## 4.5 Observed brightness

```swift
struct ObservedBrightness: Equatable, Sendable {
  let value: Double
  let source: ObservationSource
  let observedAt: ContinuousClock.Instant
  let confidence: ObservationConfidence
}
```

Sources include Apple-native readback, DDC read, post-write verification, Gamma ownership, and Shade ownership. A saved value that seeds desired or presented state remains explicitly unconfirmed and is never represented as observed brightness.

A transport-accepted command without trustworthy readback produces `acceptedUnverified`, not an `ObservedBrightness`. Only evidence-backed outcomes may produce `applied`.

## 5. Concurrency model

## 5.1 Main actor

The main actor owns:

- engine/session snapshots;
- generation changes;
- method installation and publication;
- AppKit windows;
- Core Graphics Gamma calls when required by implementation constraints;
- frontend callbacks.

It never performs:

- IORegistry traversal;
- DDC sleeps;
- DDC reads/writes;
- service matching;
- retry delays;
- filesystem export;
- heavy diagnostic rendering.

## 5.2 DDC discovery actor

One actor serializes IORegistry enumeration and service matching.

```swift
actor DDCDiscoveryActor {
  func discover(
    topology: DisplayTopologySnapshot
  ) async -> [DDCServiceCandidate]
}
```

Discovery is globally serialized initially because the adapted implementation has shared assumptions and the cost is low relative to correctness.

## 5.3 DDC transport lanes

The first implementation may keep one global actor for all I/O to preserve current safety.

The architecture must permit later lanes keyed by `PhysicalControlResourceID`:

```text
one actor per physical IOAV service
no concurrent commands to the same service
independent services may progress independently
```

A move from global serialization requires hardware evidence showing no shared IOAV race.

## 5.4 Clocks and delays

All policy delays use an injectable clock or scheduler.

Do not embed `DispatchQueue.asyncAfter` in policy code. Tests must be able to advance:

- topology settle delay;
- write coalescing;
- readback verification delay;
- retry backoff;
- continuity expiry;
- diagnostics retention.

AppKit animation timing may remain platform-owned when it does not affect engine correctness.

## 5.5 Cancellation and generations

Every asynchronous operation carries:

- engine generation;
- session generation;
- operation ID;
- physical resource ID.

A result is publishable only when all required identities still match.

Cancellation is cooperative, but correctness never depends solely on cancellation. A stale result must be rejected even if the underlying private call cannot be canceled.

## 6. Snapshot publication

The engine publishes immutable snapshots rather than exposing mutable backend objects.

```swift
protocol MonitorEngineObserving: AnyObject {
  @MainActor
  func engineDidPublish(_ snapshot: MonitorEngineSnapshot)
}
```

An `AsyncStream` or Observation-backed adapter is also acceptable.

Rules:

- snapshot publication is main-actor isolated;
- handlers are rearmed before publication when one-shot observation is used;
- no private handles cross the presentation boundary;
- a snapshot is internally self-consistent for one generation;
- ordering is stable by persistent display identity, not incidental backend order.

## 7. Installation transaction

Installing a new control method is a domain-aware transaction:

1. Resolve candidates from immutable input and identify old/new domains.
2. Acquire or construct the candidate in its neutral state without mutating current ownership where possible.
3. Establish initial observed state without a write when possible.
4. Validate generation, resource identity, and rollback evidence.
5. For same-domain transitions, transfer only a confirmed compatible target.
6. For cross-domain transitions, never copy the old normalized desired value; use the selected domain’s own desired value only for explicit user selection, and neutral state for automatic fallback unless a qualified bridge exists.
7. Neutralize conflicting MyMonitor-owned software attenuation before making another software domain non-neutral.
8. Mark the new owner and publish active state only after installation succeeds.
9. Release the old owner in an order that prevents stale teardown and double-dimming.
10. Record the transition and rollback outcome.

Where resource constraints require releasing the old owner first, the session enters explicit recovering state and retains enough evidence to restore the prior owner or report an unavailable state. Silent half-transition is prohibited.

## 8. Terminal teardown boundary

Normal method replacement may await asynchronous `teardown()`. Application termination may not.

The main-actor coordinator exposes a synchronous, idempotent terminal boundary that:

- enters a terminal generation immediately;
- unregisters callbacks and cancels publication synchronously;
- closes Shade windows and restores owned Gamma baselines synchronously;
- prevents DDC/discovery actors from publishing any later result without waiting for them to drain;
- never blocks termination on private hardware I/O.

Background actor cleanup may continue best-effort, but correctness and system-state restoration do not depend on awaiting it.

## 9. Failure containment

- One display failure does not fail the engine.
- One DDC service delay does not block the main actor.
- A global topology failure may produce a top-level failed state.
- A diagnostic recorder failure never blocks brightness control.
- Persistence failure leaves the live session usable and reports unsaved state.
- Private API unavailability resolves to another method rather than crashing.
- Unknown enum/status values map to explicit unsupported state.

## 10. Private API boundary

`PrivateDisplayKit` is the only place allowed to declare or call undocumented symbols.

It exposes MyMonitor-owned protocols and values:

```swift
protocol AppleNativeTransport: Sendable {
  func capability(for display: RuntimeDisplayID) async -> AppleNativeCapability
  func readBrightness(for display: RuntimeDisplayID) async throws -> Double
  func writeBrightness(_ value: Double, for display: RuntimeDisplayID) async throws
}

protocol IOAVTransport: Sendable {
  func discoverServices(
    for snapshot: DisplayTopologySnapshot
  ) async throws -> [DDCServiceCandidate]
  func readVCP(_ code: UInt8, service: DDCServiceID) async throws -> DDCValue
  func writeVCP(_ code: UInt8, value: UInt16, service: DDCServiceID) async throws
}
```

No engine file imports the bridging header or private framework symbols.

## 11. Test architecture

Tests are layered:

### Pure policy tests

- identity matching;
- control resolution;
- startup/wake policy;
- fallback safety;
- mirror/group mapping;
- desired/observed reconciliation;
- control-domain transitions and strict preference families;
- relative-adjustment baseline eligibility;
- accepted-unverified versus applied outcomes;
- migration.

### Fake-transport integration tests

- delayed service discovery;
- stale completion;
- invalid checksum;
- write accepted and verified;
- write accepted but readback delayed;
- write failure then rematch success;
- duplicate physical resource;
- wake during drag;
- teardown during write;
- first-write validation during a continuing drag;
- cross-domain transition rollback;
- synchronous terminal boundary with background work in flight;
- persistence failure.

### Platform adapter tests

Where direct unit testing is impossible, use narrow smoke tests and executable source contracts to verify symbol containment, actor boundaries, and ownership calls.

### Real hardware

Use `QA_MATRIX.md`; do not mock compatibility claims.

## 12. Rejected architecture

### Generic plugin framework

Rejected. Four known methods do not justify runtime plugins, dynamic loading, or extension discovery.

### Server or cloud backend

Rejected. It adds latency, privacy risk, accounts, availability dependencies, and no value to local display control.

### Privileged helper

Rejected without a concrete hardware requirement.

### One giant `DisplayRouter`

The current router is a useful coordinator but should not continue absorbing identity, profile storage, transport, diagnostics, and every method implementation.

### Complete rewrite in one PR

Rejected. The existing app works and contains carefully reviewed lifecycle fixes. Seams and state migrate sequentially with behavior preserved unless the ticket explicitly changes it.
