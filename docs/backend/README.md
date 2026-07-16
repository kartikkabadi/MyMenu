# MyMonitor Backend Contract

Status: **Canonical specification**  
Target: **macOS 26+, Apple silicon**  
Product: **External-monitor brightness control only**  
Reference date: **2026-07-16**

This directory defines the local display-control engine MyMonitor is allowed to become. “Backend” means the on-device system that discovers displays, resolves a control method, reconciles desired and observed brightness, persists display profiles, survives lifecycle changes, and reports truthful state to the frontend. MyMonitor does not require or permit a cloud service for its core product.

## North star

> A brightness command should reach the intended physical display predictably, or fail visibly and recoverably, without surprising startup writes, stale state, hidden fallback, or permission creep.

The engine must be narrow enough to understand, deterministic enough to test without hardware, and conservative enough to avoid damaging color calibration or leaving a monitor unusable.

## Read order

Read these documents before changing display-control code:

1. [`RESEARCH.md`](RESEARCH.md) — current implementation audit, platform constraints, competitor evidence, and adopted lessons.
2. [`PRODUCT_CONTRACT.md`](PRODUCT_CONTRACT.md) — user-visible semantics, invariants, startup/wake/reconnect policy, and non-goals.
3. [`ARCHITECTURE.md`](ARCHITECTURE.md) — module boundaries, ownership, concurrency, protocols, and data flow.
4. [`LIFECYCLE.md`](LIFECYCLE.md) — topology snapshots, state machines, generations, writes, recovery, and teardown.
5. [`IDENTITY.md`](IDENTITY.md) — durable display identity, duplicate-display handling, persistence, and migration.
6. [`CONTROL_ENGINES.md`](CONTROL_ENGINES.md) — Apple-native, DDC/CI, Gamma, and Shade contracts.
7. [`EDGE_CASES.md`](EDGE_CASES.md) — binding failure-recovery and automatic cross-domain transition traces.
8. [`DIAGNOSTICS.md`](DIAGNOSTICS.md) — structured events, failure vocabulary, privacy, support export, and observability.
9. [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) — sequential backend tickets and objective acceptance criteria.
10. [`QA_MATRIX.md`](QA_MATRIX.md) — automated, simulated, and real-hardware qualification matrix.
11. [`DECISIONS.md`](DECISIONS.md) — binding decisions and rejected alternatives.

The implementation programme is B1–B13. Method foundations land before B11 activates the final non-mutating cold-launch and continuity-based wake/reconnect policy across every control engine.

When documents disagree, the more specific requirement wins. A deliberate behavior change must update every affected backend document in the same pull request.

## Product promise

MyMonitor has one backend job:

1. Identify the connected external displays.
2. Represent each physical display with a durable local identity.
3. Determine which brightness mechanisms are safe and available.
4. Show observed state without mutating hardware merely to discover it.
5. Apply user intent through the selected mechanism.
6. Distinguish desired state from confirmed state.
7. Recover across hot-plug, wake, mode changes, mirroring, and stale services.
8. Restore system color and window state when MyMonitor releases ownership.
9. Produce privacy-scoped evidence when something fails.

## Non-negotiable invariants

### One user-facing direction

`0 = darkest` and `1 = brightest` in every public model and control path. Backend-specific ranges and inversions remain internal.

### Desired is not observed

The engine must not treat “we attempted a write” as “the display now has this value.” It maintains per-domain desired state, observed state, confirmed continuity state, and explicit write outcome. Transport acceptance without evidence remains unverified.

### Explicit choices are strict

Automatic may cross control families. Explicit Hardware stays in Apple Native/DDC; explicit Software stays in Gamma/Shade.

### Domains do not share numeric intent

Hardware, Gamma, and Shade values are normalized for their own active domain. They are not copied across domains merely because each uses `0...1`.

### Discovery is non-mutating by default

Cold launch, first connection, topology enumeration, identity matching, and capability discovery must not visibly change brightness or Gamma merely to determine availability.

### No surprising cold-launch restore

A cold application launch adopts observed hardware brightness when it can read it. Saved state may seed the interface only when observation is unavailable; it must not automatically overwrite a monitor on launch.

### Lifecycle intent is explicit

Cold launch, wake, transient reconnect, topology change, user Retry, method change, and profile change are distinct reasons. A generic `force: Bool` is not an acceptable long-term policy input.

### One owner per physical control resource

A physical DDC service, Gamma curve, or Shade window has exactly one live session owner. Stale teardown cannot affect a replacement owner.

### No invisible mid-command fallback

A transient write failure does not silently switch to a second dimming method while the first method may already have changed the display. Fallback selection happens through an explicit generation-safe transition.

### Local-only core

No account, analytics SDK, network request, remote configuration, cloud database, or server dependency belongs in brightness discovery or control.

### Private APIs are contained

All undocumented Apple interfaces live behind a small MyMonitor-owned adapter boundary. Product state, policies, and tests must not import private symbols.

### Hardware claims require hardware evidence

A successful build and fake-transport test prove architecture, not monitor compatibility. Release claims require the matrix in `QA_MATRIX.md`.

## Target architecture

```text
DisplayPresentationStore
  optimistic UI and user intent
              │
              ▼
MonitorEngine @MainActor
  published sessions and lifecycle state
       │                  │
       ▼                  ▼
TopologyProvider      DisplayProfileStore
immutable snapshots   durable identity and preferences
       │                  │
       └───────┬──────────┘
               ▼
ControlResolver
reason + topology + profile + safety + capability evidence
               │
               ▼
DisplayControlSession
 desired / observed / health / current operation
   ├── AppleNativeSession
   ├── DDCSession ──► DDC transport actors
   ├── GammaSession
   └── ShadeSession
               │
               ▼
Public macOS APIs + PrivateDisplayKit
```

## Relationship to the frontend contract

The frontend renders presentation state and emits intent. It must not:

- enumerate displays;
- construct persistent identity;
- probe control methods;
- choose fallback order;
- read or write Apple display interfaces;
- own DDC timing;
- capture or restore Gamma tables;
- create Shade windows;
- interpret topology callbacks;
- persist display profiles;
- infer write success;
- manufacture diagnostics.

The backend must not:

- select typography, layout, symbols, or copy structure;
- know whether state is rendered in the popover or Settings;
- require the frontend to expose private method names;
- block the main actor while waiting for hardware.

## Merge gates for backend work

Every backend pull request must satisfy all applicable gates:

- Swift tests with warnings treated as errors.
- Deterministic fake-clock and fake-transport tests for changed policy.
- The binding traces in `EDGE_CASES.md` when failure recovery or control-domain transitions change.
- Frontend contract validation.
- Backend contract validation.
- Generated Xcode project has zero drift.
- Xcode Debug and Release builds with warnings treated as errors.
- `git diff --check`.
- No private Apple symbol outside the approved adapter module.
- No hardware operation on the main actor.
- No new boolean that collapses multiple lifecycle reasons when a typed enum is required.
- No write path that updates observed state without evidence.
- No persisted raw support diagnostic containing serial numbers, EDID bytes, IORegistry paths, usernames, or unrelated system state.
- Real-hardware validation when the change affects capability, writes, Gamma, Shade, topology, identity, or wake behavior.

## Definition of done for the backend programme

The programme is complete only when:

1. Desired, observed, and write status are independent first-class state.
2. Cold launch does not mutate a monitor as part of discovery.
3. Lifecycle behavior is reason-aware and deterministic.
4. Display profiles survive ordinary port, dock, reconnect, and process changes with documented confidence.
5. Apple-native, DDC, Gamma, and Shade use isolated control-session contracts.
6. DDC behavior is testable without IOAV hardware.
7. Gamma uses a calibration-preserving per-display baseline strategy and is disabled when unsafe.
8. Structured diagnostics explain why a method was selected and why an operation failed.
9. The documented hardware matrix and binding edge-case traces have been executed for a release candidate.
10. A contributor can implement or review a backend ticket without guessing product semantics.
