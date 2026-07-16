# Diagnostics, Failures, and Support Evidence

This document defines structured local diagnostics, typed failures, privacy rules, retention, support export, and failure presentation requirements.

## 1. Goals

Diagnostics must answer:

- What topology did MyMonitor observe?
- Why did it match this runtime display to this profile?
- Why did it choose Apple Native, DDC, Gamma, or Shade?
- What did the user request?
- What value was observed before and after the operation?
- Which generation and resource owned the operation?
- Did the write queue, execute, retry, verify, fail, or become obsolete?
- Did wake, hot-plug, mirroring, or teardown invalidate it?
- What can the user safely try next?

Diagnostics must not become telemetry, a general system inventory, or a privacy leak.

## 2. Structured event model

```swift
struct EngineEvent: Codable, Equatable, Sendable {
  let sequence: UInt64
  let monotonicTimestamp: Duration
  let wallClockTimestamp: Date?
  let category: EngineEventCategory
  let level: EngineEventLevel
  let engineGeneration: UInt64?
  let sessionGeneration: UInt64?
  let operationID: UUID?
  let displaySupportID: String?
  let resourceSupportID: String?
  let payload: EngineEventPayload
}
```

Wall-clock time is optional. Ordering relies on a monotonic sequence and duration.

## 3. Event categories

```swift
enum EngineEventCategory: String, Codable, Sendable {
  case lifecycle
  case topology
  case identity
  case capability
  case methodSelection
  case read
  case write
  case verification
  case recovery
  case persistence
  case gamma
  case shade
  case teardown
  case privacy
}
```

## 4. Event levels

- `debug` — useful implementation evidence retained only in development or bounded local history.
- `info` — normal lifecycle transitions.
- `notice` — fallback, provisional capability, continuity restore, or migration.
- `warning` — degraded behavior with a usable path.
- `error` — failed operation or unavailable display.
- `critical` — engine-wide failure or inability to restore owned system state.

No level triggers network transmission.

## 5. Typed failure vocabulary

```swift
enum ControlFailure: Equatable, Codable, Sendable {
  case topology(TopologyFailure)
  case identity(IdentityFailure)
  case appleNative(AppleNativeFailure)
  case ddc(DDCFailure)
  case gamma(GammaFailure)
  case shade(ShadeFailure)
  case persistence(PersistenceFailure)
  case lifecycle(LifecycleFailure)
  case cancelled
  case superseded
}
```

### Topology failures

```swift
enum TopologyFailure {
  case enumerationFailed
  case unstableBeyondDeadline
  case screenMappingUnavailable
  case inconsistentMirrorSet
  case changedDuringOperation
}
```

### Identity failures

```swift
enum IdentityFailure {
  case insufficientEvidence
  case ambiguousCandidates
  case duplicateAssignment
  case migrationConflict
  case profileDecodeFailed
}
```

### Apple Native failures

```swift
enum AppleNativeFailure {
  case symbolUnavailable
  case capabilityUnavailable
  case readRejected(code: Int32?)
  case writeRejected(code: Int32?)
  case invalidValue
  case verificationMismatch(requested: Double, observed: Double)
}
```

### DDC failures

See `CONTROL_ENGINES.md`; include no service, ambiguity, timeout, checksum, invalid range, rejection, mismatch, stale service, unsupported architecture, and cancellation.

### Gamma failures

```swift
enum GammaFailure {
  case baselineUnavailable
  case invalidBaseline
  case unsafeHDRState
  case ownershipConflict
  case applyFailed(code: Int32?)
  case restoreFailed(code: Int32?)
  case topologyChanged
}
```

### Shade failures

```swift
enum ShadeFailure {
  case screenUnavailable
  case windowCreationFailed
  case ownershipConflict
  case topologyChanged
  case applicationTerminating
}
```

### Lifecycle failures

```swift
enum LifecycleFailure {
  case baselineUnavailableForRelativeAdjustment
  case firstWriteValidationFailed
  case continuityTargetIncompatibleDomain
  case transitionRollbackFailed
  case applicationTerminating
}
```

### Persistence failures

```swift
enum PersistenceFailure {
  case decodeFailed
  case encodeFailed
  case saveFailed
  case migrationFailed
  case unsupportedSchema(Int)
}
```

Failures may have internal associated metadata, but exported reports use redacted summaries.

## 6. Event payloads

Use typed payloads rather than arbitrary string dictionaries.

Examples:

```swift
enum EngineEventPayload: Codable, Equatable, Sendable {
  case lifecycleStarted(reason: ReconfigurationReason)
  case topologyCaptured(TopologyEventSummary)
  case identityMatched(IdentityEventSummary)
  case capabilityObserved(CapabilityEventSummary)
  case methodResolved(MethodResolutionSummary)
  case operationQueued(OperationEventSummary)
  case operationAttempted(OperationAttemptSummary)
  case operationVerified(OperationVerificationSummary)
  case operationFailed(OperationFailureSummary)
  case fallbackSelected(FallbackEventSummary)
  case profileMigrated(MigrationEventSummary)
  case resourceReleased(ResourceReleaseSummary)
}
```

A free-form message may accompany the event for developer readability, but tests and support rendering rely on typed fields.

## 7. Required causal evidence

### Lifecycle event

- reason;
- previous/new generation;
- cached session count;
- quiet-window and deadline timing;
- completion outcome.

### Topology event

- external display count;
- mirror-set count;
- full/partial mirror classification;
- topology signature;
- screen mapping availability;
- no raw window or desktop contents.

### Identity event

- support ID;
- confidence;
- evidence categories used;
- number of alternatives;
- whether connection-bound;
- no raw serial, EDID, or path in exported form.

### Capability event

- candidate method;
- capability state;
- evidence source;
- duration;
- typed failure;
- topology signature.

### Method resolution event

- requested preference;
- ordered candidates;
- selected method;
- fallback reason;
- warnings/safety exclusions.

### Operation event

- control domain;
- desired normalized value;
- observed value before/after when available;
- outcome confidence: accepted-unverified versus evidence-backed applied;
- operation sequence;
- attempt count;
- duration;
- write/verification result;
- whether superseded;
- never raw packet contents by default.

## 8. Privacy redaction

Exported diagnostics must never include:

- user name;
- home-directory or arbitrary filesystem path;
- window title;
- running application list;
- clipboard content;
- document content;
- account identifier;
- network address;
- raw EDID bytes;
- raw monitor serial;
- raw IORegistry path;
- raw IOAV pointer/handle;
- full crash memory or stack data unrelated to MyMonitor;
- unrelated USB/device inventory.

Allowed support evidence:

- MyMonitor version/build;
- macOS version;
- Mac architecture and broad model family when useful;
- external display support IDs;
- user-visible display name after newline/control-character cleaning;
- connection class such as USB-C, DisplayPort, HDMI, dock/unknown;
- requested and active method;
- desired/observed brightness;
- configured range;
- lifecycle reason;
- typed errors;
- durations and attempts;
- hashed topology/resource signatures.

## 9. Support IDs

Display and resource support IDs use an install-specific salt.

Properties:

- stable across logs in one installation;
- stable across reconnect when identity matches;
- not reversible from the export alone;
- no more than 12 printable characters;
- distinguish display profile from physical resource.

Example:

```text
Display: D-A7F2-19C4
Resource: R-48B1-03AF
```

## 10. Retention

Default production retention:

- maximum 1,000 structured events;
- maximum encoded size 512 KiB;
- maximum age 7 days;
- oldest-first eviction;
- one current and one previous session file at most;
- local Application Support storage;
- user can clear diagnostics from Settings;
- no background upload.

The first implementation may start with an in-memory ring plus explicit export. Persistent retention is introduced only with tests for privacy, corruption, and bounds.

## 11. Storage integrity

- version the event envelope;
- decode failure starts a clean recorder and retains the corrupt file only when useful for local debugging;
- never block control because diagnostics cannot save;
- write atomically;
- cap event message length;
- sanitize control characters;
- avoid recursive diagnostics when the recorder fails;
- diagnostics actor has no display-control authority.

## 12. Support report

The user-facing report contains:

1. application and platform summary;
2. current engine state;
3. connected and remembered display summaries;
4. requested/active methods;
5. desired, observed, and write status;
6. identity confidence and connection-bound warning;
7. current failures and suggested next action;
8. recent relevant event timeline;
9. privacy statement.

Example structure:

```text
MyMonitor Diagnostics

Application
Version: 0.2.0 (42)
macOS: 26.4
Architecture: arm64
Engine: degraded

Display D-A7F2-19C4
Name: Dell U2723QE
Connection: USB-C / direct
Identity: high confidence
Requested: Automatic
Active: DDC/CI
Desired: 42%
Observed: 40% at 06:18:22
Write: failed — verification mismatch
Domain: hardware
Recovery: one service rematch attempted

Recent events
+0.000 wake generation 18 started
+0.161 topology captured, 1 external display
+0.229 DDC service matched, high evidence
+0.412 hardware read 40/100
+1.203 write requested 42/100
+1.418 verification observed 40/100

Privacy
No serial numbers, EDID bytes, IORegistry paths, window titles, documents,
accounts, or unrelated device inventory are included.
```

## 13. Suggested actions

Failure mapping to actions is policy, not ad hoc UI text.

Examples:

- no service after wake → Retry hardware control;
- ambiguous identity → reconnect directly or include diagnostics;
- verification mismatch → try Retry; do not continuously fight monitor;
- Gamma unsafe in HDR → use Display shade or Hardware control;
- Shade screen unavailable → exit mirroring/topology transition and Retry;
- persistence save failed → controls remain active; preferences may not survive restart.

The backend supplies an action identifier. The frontend owns final localized copy.

## 14. OSLog

`Logger`/OSLog may mirror concise developer events during development and production troubleshooting.

Rules:

- structured recorder remains canonical support evidence;
- private fields use OSLog privacy markers;
- no raw serial, EDID, or path in public log interpolation;
- release logs remain low-volume;
- slider intermediate values are not logged individually;
- no signpost leaks private identity.

## 15. Metrics without analytics

Local aggregate counters are permitted for diagnostics:

- discovery duration;
- number of retries;
- write latency percentiles within current session;
- failure counts by typed class;
- method-transition count;
- topology-generation count.

They remain local and resettable. MyMonitor does not upload product analytics.

## 16. Tests

Required tests:

- each typed failure renders a stable support summary;
- raw serial, EDID, and IORegistry path are redacted;
- user names and home paths are scrubbed from injected test values;
- support IDs are stable per salt and distinct across salts;
- event ordering uses sequence even when wall-clock changes;
- ring buffer evicts oldest events;
- size and age bounds hold;
- corrupt storage does not block engine startup;
- recorder failure does not block writes;
- operation supersession removes misleading success/failure from current status;
- report differentiates desired, accepted-unverified, and observed/applied values;
- report includes control domain and strict preference-family outcome;
- baseline-unavailable relative commands produce no write;
- fallback reason appears;
- diagnostics can be cleared;
- report export is explicit user action.

## 17. Rejected diagnostics designs

### Unbounded text log

Rejected for privacy, size, and weak machine-testability.

### Upload-on-failure telemetry

Rejected. Core product remains local-only.

### Full `ioreg` or `system_profiler` dump

Rejected. It exposes unrelated hardware and personal system data.

### Raw DDC packet logging by default

Rejected. Packet-level logging may exist only in a short-lived developer build behind an explicit compile-time flag.

### Treating last tier as proof

Rejected. Last active method is historical context, not current capability evidence.
