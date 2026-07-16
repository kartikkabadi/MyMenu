# Backend Implementation Plan

Backend work proceeds as a sequence of small pull requests. Every ticket must preserve a working app, add deterministic tests for new policy, update affected specifications, and state which real-monitor checks were performed.

The ordering is deliberate: establish truthful state and topology first, isolate low-level platform risk, migrate identity, make every control method capable of non-mutating installation, and only then switch the whole product to the new cold-launch/wake policy. No ticket is allowed to reach forward and partially implement a later method engine.

## B0 — Contract

Land the docs in this directory. No runtime changes.

## B1 — Contracts and fakes

Add hardware-independent IDs, control domains, per-domain desired state, confirmed continuity targets, accepted-unverified/applied outcomes, lifecycle reasons, typed failures, clock, topology, profile-store, and control-adapter protocols. Add deterministic fake clocks and transports. Define the synchronous terminal boundary while keeping the existing router in production.

## B2 — Truthful brightness state

Separate per-domain desired brightness, observed brightness, optimistic presentation, confirmed continuity state, and write status. Add `acceptedUnverified` distinct from evidence-backed `applied`. Older operations may not overwrite newer state. Failed or unverified writes preserve desired state but do not claim observation or continuity.

This ticket may wrap current methods with provisional evidence; it does not redesign discovery or fallback.

## B3 — Topology snapshots and lifecycle scaffolding

Add immutable topology snapshots, mirror sets, topology signatures, continuity tokens, typed reconfiguration reasons, engine/session generations, and a bounded quiet-window settle policy.

This ticket routes existing production behavior through typed context but does **not** yet activate the final non-mutating cold-launch or continuity-restore policy. Those semantics cut over in B11 after every method can install, observe, suspend, resume, and release through the new contracts.

## B4 — Platform adapter boundary

Move low-level undocumented platform declarations and calls behind a small MyMonitor-owned adapter. Engine, policy, presentation, diagnostics, and tests consume only MyMonitor types.

Existing behavior remains intact. This boundary must land before durable identity or new control methods add more consumers of IORegistry, DisplayServices, CoreDisplay, or IOAV evidence.

## B5 — Durable identity and v2 migration

Add display fingerprints, match confidence, duplicate handling, global assignment, versioned profiles, privacy-safe support IDs, and idempotent migration from runtime-ID-based preferences.

Identity uses public evidence plus values supplied by the B4 adapter; it adds no new direct private-platform call.

## B6 — Apple Native control

Add capability, read, write, readback, health, and resolver priority for compatible displays. Do not probe by changing brightness during launch.

The method supports installation without applying a saved value so B11 can adopt readable state on cold launch.

## B7 — DDC discovery

Add a serialized discovery actor, service candidates, global assignment, physical-resource IDs, typed failures, and deterministic transport traces. Cold discovery reads luminance but does not write it.

The current no-op write probe is removed here. Write capability becomes provisional until explicit use.

## B8 — DDC writing and verification

Add operation-aware coalescing, final-write priority, one bounded stale-service recovery, verification, timing policy, and degraded state. No retry may run indefinitely and no uncertain write may silently add a second dimming method.

## B9 — Baseline-preserving Gamma

Capture and validate each display’s baseline transfer table, compose dimming from that baseline, restore per display, recapture after lifecycle changes, and exclude unsafe HDR/EDR states. Remove visible capability probing.

The method supports hidden installation and observation without changing the transfer table until policy explicitly permits application.

## B10 — Shade and logical groups

Move Shade behind the control-session contract. Complete full-mirror receipts, partial-mirror independence, shared-resource grouping, mapping recovery, screen-capture behavior, neutral-state installation, and non-stacking transitions with Gamma.

The method can construct or validate ownership without ordering a dimming window front during cold discovery.

## B11 — Reason-aware lifecycle policy cutover

Cut over cold launch, first connection, wake, transient reconnect, Retry, strict explicit preference families, relative-adjustment baseline policy, and domain-aware method/profile transitions across all methods. Remove launch-time DDC/Gamma mutation only here, after replacement methods support the contract.

Tests cover the full cross-method lifecycle rather than method-specific substitutes.

## B12 — Structured local diagnostics

Add bounded structured events, typed failure summaries, privacy redaction, support IDs, explicit export, and clear behavior. No network reporting.

The event model consumes the stable lifecycle, identity, method, and operation vocabulary established by B1–B11.

## B13 — Qualification and release gate

Execute the hardware matrix, record evidence, fix critical failures in focused follow-up PRs, and complete the signed/notarized release checklist.

## Ticket gates

Each ticket requires:

- Swift tests with warnings as errors;
- relevant fake-clock and fake-transport coverage;
- frontend and backend contract checks;
- deterministic project generation;
- Debug and Release builds;
- whitespace validation;
- no unreviewed platform calls outside the adapter boundary;
- real-monitor validation when behavior touches discovery, writes, identity, lifecycle, Gamma, Shade, or grouping.

## Deferred

Adaptive per-monitor timing, parallel DDC lanes, manual duplicate pairing, capability-string parsing, startup-mode settings, persistent multi-session diagnostics, automation APIs, synchronization, native OSD, and non-brightness monitor controls remain out of scope until evidence justifies a new decision.
