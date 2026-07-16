# Backend Decisions

This document records binding backend decisions. A decision changes only through a pull request that identifies new platform or hardware evidence, updates affected specifications and tests, explains migration, and states compatibility impact.

## B-D001 — MyMonitor has no server backend

**Status:** Accepted  
**Decision:** Core display discovery, identity, control, persistence, and diagnostics remain local to the Mac.

**Rejected:** Accounts, cloud state, remote configuration, analytics, or an online service required for brightness control.

**Rationale:** A network dependency adds latency, privacy risk, availability failure, and product scope without improving local hardware control.

## B-D002 — Preserve the current engine; migrate through seams

**Status:** Accepted  
**Decision:** Keep the reviewed generation, lifecycle, Gamma ownership, and Shade fixes while extracting contracts ticket by ticket.

**Rejected:** One monolithic backend rewrite.

**Rationale:** The current code already solves difficult races. A rewrite would discard evidence and make hardware regressions hard to isolate.

## B-D003 — Desired, observed, and presented brightness are distinct

**Status:** Accepted  
**Decision:** The engine maintains independent desired state, observed state, and optimistic presentation state, plus explicit write status.

**Rejected:** Updating “current brightness” immediately after calling a setter and treating that as hardware truth.

**Rationale:** Hardware writes can fail, be delayed, or apply despite a timeout. Truthful state is necessary for recovery and diagnostics.

## B-D004 — Cold discovery is non-mutating

**Status:** Accepted  
**Decision:** Cold launch and first connection do not write brightness or alter Gamma merely to prove capability.

**Rejected:** DDC no-op write validation and temporary Gamma dimming during launch discovery.

**Rationale:** Even visually neutral commands can wake or disturb monitors. Observation should precede mutation.

## B-D005 — Cold launch adopts readable hardware state

**Status:** Accepted  
**Decision:** When brightness is readable, cold launch adopts it rather than restoring the saved desired value.

**Rejected:** Automatically writing the last saved value every time the app launches.

**Rationale:** The user may have changed the monitor outside MyMonitor. Launch should not surprise them.

## B-D006 — Wake restore requires continuity

**Status:** Accepted  
**Decision:** Wake may restore one confirmed continuity target when the same process previously held reliable observed state, identity continuity remains strong, and the restore is bounded to one generation.

**Rejected:** Never restoring after wake; always restoring after every reconnect; repeatedly fighting until the monitor matches.

**Rationale:** Some monitors reset on wake, while unconditional restores can target the wrong or intentionally changed display.

## B-D007 — Lifecycle reasons are typed

**Status:** Accepted  
**Decision:** Cold launch, first connection, wake, transient reconnect, topology change, mode change, Retry, method change, and profile change are distinct policy inputs.

**Rejected:** A generic `force: Bool` as the long-term lifecycle model.

**Rationale:** The same capability work has different write permission and continuity semantics depending on why it runs.

## B-D008 — One immutable topology snapshot per generation

**Status:** Accepted  
**Decision:** Identity, mirroring, screen mapping, and control resolution for a generation use one captured topology snapshot.

**Rejected:** Repeated live Core Graphics/AppKit queries throughout one asynchronous reconfiguration.

**Rationale:** Live topology can change between calls and create internally inconsistent decisions.

## B-D009 — Persistent identity is not `CGDirectDisplayID`

**Status:** Accepted  
**Decision:** Runtime IDs remain runtime handles. Profiles use a versioned fingerprint, confidence, and connection evidence.

**Rejected:** Raw display ID or display name as the durable preference key.

**Rationale:** Runtime IDs and names are not stable or unique enough across ordinary hardware changes.

## B-D010 — Ambiguity prevents automatic restore

**Status:** Accepted  
**Decision:** Two equally plausible display-profile matches remain separate and do not receive an automatic saved-state restore.

**Rejected:** Picking the first candidate or silently merging identical monitors.

**Rationale:** A wrong-monitor brightness write is worse than requiring a later retry or manual distinction.

## B-D011 — Internal control order is Native, DDC, Gamma, Shade

**Status:** Accepted  
**Decision:** Automatic resolution prefers Apple Native, then DDC/CI, safe Gamma, and Shade.

**User-facing vocabulary:** Automatic, Hardware control, Software control, Display shade.

**Rationale:** Native hardware integration is preferable where supported; DDC is the general hardware path; software methods are fallbacks.

## B-D012 — Uncertain writes do not silently stack a fallback

**Status:** Accepted  
**Decision:** A transient or uncertain write failure triggers bounded same-method recovery and explicit degraded state. Any fallback transition occurs through a new generation-safe method transaction.

**Rejected:** Adding Gamma or Shade immediately after a DDC timeout.

**Rationale:** The original write may already have changed the monitor; stacking a second method can double-dim it.

## B-D013 — DDC discovery is read-only

**Status:** Accepted  
**Decision:** DDC cold discovery matches a service and reads VCP `0x10`. Write capability is validated on the first explicit user write.

**Rejected:** Writing the current value during discovery.

**Rationale:** Read and write support are separate evidence; launch should remain non-mutating.

## B-D014 — DDC failures are typed and bounded

**Status:** Accepted  
**Decision:** Service, checksum, timeout, range, write, verification, stale-resource, topology, and cancellation failures remain distinct. Retry counts and delays are bounded.

**Rejected:** `Bool`/`nil` failure collapse and unbounded retry loops.

**Rationale:** Recovery and support guidance depend on cause.

## B-D015 — Begin with globally serialized DDC I/O

**Status:** Accepted as baseline  
**Decision:** Preserve one serialized DDC transport lane initially. The architecture permits later per-resource actors.

**Evidence required to change:** Real hardware must show independent services can progress concurrently without shared IOAV races.

**Rationale:** Correctness is more important than speculative parallelism.

## B-D016 — Gamma uses captured baseline tables

**Status:** Accepted  
**Decision:** Capture a per-display transfer table, compose dimming from it, and restore it under owner control.

**Rejected:** Generic formula-only ownership and temporary dimming as capability detection.

**Rationale:** Baseline composition better preserves calibration and channel relationships.

## B-D017 — Gamma is unavailable when safety is uncertain

**Status:** Accepted  
**Decision:** HDR/EDR, invalid baseline, ownership conflict, virtual targets, or unqualified mirror state may exclude Gamma and select Shade.

**Rejected:** Continuously forcing Gamma because the API call returned success once.

**Rationale:** Software dimming must not damage color behavior or fight the system.

## B-D018 — Shade remains the universal visual fallback

**Status:** Accepted  
**Decision:** Shade is used when a visible external `NSScreen` mapping exists and safer methods are unavailable or explicitly rejected.

**Rejected:** Treating Shade as physical brightness or silently claiming hardware state.

**Rationale:** Shade is predictable and reversible but semantically different from backlight control.

## B-D019 — Physical resources are first-class

**Status:** Accepted  
**Decision:** A session identifies the physical control resource separately from the logical display target.

**Rejected:** Assuming one runtime display always equals one independent backlight.

**Rationale:** Mirroring, PBP, duplicate IOAV candidates, and replacement owners require resource-level serialization.

## B-D020 — Private platform calls are isolated

**Status:** Accepted  
**Decision:** Undocumented Apple declarations and calls live behind one small adapter boundary exposing MyMonitor-owned types.

**Rejected:** Private symbols in the router, presentation, policy, diagnostics, or tests.

**Rationale:** This contains OS maintenance risk and keeps most of the engine hardware-independent.

## B-D021 — Direct signed distribution is the target

**Status:** Accepted  
**Decision:** Plan public releases around Developer ID signing, notarization, stapling, and Gatekeeper validation.

**Rejected:** Claiming Mac App Store compatibility while hardware control depends on undocumented interfaces; bypassing quarantine.

**Rationale:** Apple’s App Review rules require public APIs for App Store apps. MyMonitor must use the normal direct-distribution trust path.

## B-D022 — No privileged helper

**Status:** Accepted  
**Decision:** The backend remains in the app process unless a future concrete requirement proves a helper necessary.

**Rejected:** A daemon, root helper, driver, kernel extension, or permission escalation added for architectural appearance.

**Rationale:** Current control methods do not justify that security and lifecycle complexity.

## B-D023 — Diagnostics are structured, bounded, local, and redacted

**Status:** Accepted  
**Decision:** Record typed local events with retention limits and privacy-safe support IDs. Export occurs only on user action.

**Rejected:** Cloud telemetry, unbounded text logs, raw system inventory, raw EDID/serial/path export.

**Rationale:** Hardware bugs need causal evidence without turning MyMonitor into a data collector.

## B-D024 — Hardware qualification is a release gate

**Status:** Accepted  
**Decision:** Builds and fake transports validate architecture. Physical monitor claims require the matrix in `QA_MATRIX.md`.

**Rejected:** “Works with all monitors” based on API success or competitor behavior.

**Rationale:** Monitor firmware, cable, dock, topology, and OS version materially change behavior.

## B-D025 — Brightness remains the only monitor command

**Status:** Accepted  
**Decision:** The backend controls luminance only.

**Rejected:** Volume, mute, contrast, input, power, color gains, resolution, HDR boosting, or virtual display scope in this programme.

**Rationale:** Reliability comes from a narrow surface and a complete qualification matrix.

## B-D026 — `UserDefaults` may back a versioned profile store

**Status:** Accepted as initial storage  
**Decision:** A versioned Codable profile snapshot may use `UserDefaults` behind a storage protocol.

**Rejected:** Scattered preference keys in engine code; a database without need.

**Rationale:** The dataset is small, but schema/migration and testability still require one store boundary.

## B-D027 — Screen-capture behavior for Shade remains an explicit B10 decision

**Status:** Pending evidence  
**Decision:** B10 must test and record whether Shade appears in screenshots and screen sharing.

**Rationale:** The correct behavior involves user expectation and AppKit window-sharing behavior, not only implementation convenience.

## B-D028 — Compatibility exceptions are data, not branching folklore

**Status:** Accepted  
**Decision:** Known monitor/path exceptions must be represented by reviewed evidence and typed policy data.

**Rejected:** Scattered model-name checks and unexplained sleeps.

**Rationale:** Exceptions otherwise accumulate into an engine no one can reason about.

## B-D029 — Only confirmed continuity state is automatically restorable

**Status:** Accepted  
**Decision:** Wake or transient reconnect may automatically restore only the last confirmed continuity target: either a reliable observed value adopted as the stable live-session state or a user-committed desired value later confirmed applied. A newer failed, provisional, queued, writing, or unverified desired value remains visible as user intent but requires explicit Retry or a new user action.

The confirmed continuity target is process-local. Adopting observed hardware state does not silently overwrite the persisted user preference.

**Rejected:** Turning a failed pre-sleep write into an automatic post-wake write merely because it was the newest saved intent.

**Rationale:** Continuity restoration should recover a known prior state, not silently retry an operation whose outcome was already uncertain.

## B-D030 — Explicit method choices do not cross families

**Status:** Accepted
**Decision:** Hardware control resolves only Apple Native or DDC. Software control resolves only Gamma or Shade. Automatic is the only choice that crosses hardware and software families.

**Rejected:** Treating explicit Hardware or Software as a weak hint that may silently select the opposite family.

**Rationale:** A user may choose Software because hardware control is broken, or Hardware because software attenuation is undesirable. Crossing families undermines the setting and can reintroduce the exact failure the user avoided.

## B-D031 — Transport acceptance is not applied state

**Status:** Accepted
**Decision:** A command accepted without trustworthy observation is `acceptedUnverified`. `applied` always includes evidence-backed observed state.

**Rejected:** Treating a zero/error-free return code or write-only compatibility mode as proof that brightness changed.

**Rationale:** Private setters and DDC writes can report success while firmware ignores, delays, clamps, or misapplies the command. Truthful state requires a separate outcome.

## B-D032 — Desired and continuity state are control-domain scoped

**Status:** Accepted
**Decision:** Hardware, Gamma, and Shade keep separate desired state. Continuity targets record their domain and are restored only through compatible semantics.

**Rejected:** One persisted normalized brightness copied across Apple Native, DDC, Gamma, and Shade.

**Rationale:** Identical normalized numbers do not represent equal luminance across physical backlight and attenuation layers. Blind transfer causes jumps and double-dimming.

## B-D033 — Relative adjustment requires a process-local baseline

**Status:** Accepted
**Decision:** Relative commands require current observation, a confirmed continuity target, or an absolute user selection made in the current process. An unconfirmed persisted seed alone cannot drive a hotkey increment.

**Rejected:** Adding a step to a stale saved number when actual monitor brightness is unreadable.

**Rationale:** A relative command is meaningful only relative to a known or explicitly re-established baseline. An absolute slider selection remains available.

## B-D034 — First-write validation is serialized

**Status:** Accepted
**Decision:** A write-unvalidated resource permits one latest-value validation operation and at most one newest catch-up/final operation. New pointer events replace pending intent instead of creating more writes.

**Rejected:** Sending every drag value before the first operation establishes write health.

**Rationale:** A broken or unsupported monitor should not receive a burst of speculative writes, and stale validation must not override the final user value.

## B-D035 — Termination has a synchronous terminal boundary

**Status:** Accepted
**Decision:** Normal replacement teardown may be asynchronous. Application termination synchronously invalidates publication and releases main-thread-owned Gamma/Shade/callback resources without waiting for private hardware actors.

**Rejected:** Awaiting DDC or discovery teardown during app termination, or relying only on later asynchronous cleanup to restore visible system state.

**Rationale:** Termination must be prompt and deterministic while still guaranteeing no late work can resurrect state or leave process-owned visual effects behind.
