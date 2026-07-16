# Backend Research

Reference date: **2026-07-16**

This document records the evidence behind the backend contract. It separates current MyMonitor facts, public platform constraints, undocumented-interface risk, mature-tool lessons, and user-reported compatibility patterns.

## Research method

The audit covered:

- MyMonitor `main` after PR #20, including `DisplayRouter`, DDC, Gamma, Shade, policies, persistence, diagnostics, build configuration, and tests.
- Apple public Core Graphics and AppKit API documentation.
- Apple’s current App Review Guidelines.
- MonitorControl source and issue history.
- Lunar source and current public changelog.
- BetterDisplay’s current public compatibility and feature documentation.
- DDC/CI and MCCS behavior relevant to VCP code `0x10` luminance.

Research sources are linked at the end. Competitor behavior is used as evidence, not as a design to copy.

---

# 1. Current MyMonitor backend audit

## 1.1 Strengths worth preserving

### Generation-safe reconfiguration

The current router:

- increments a reconfiguration generation;
- keeps cached rows while probing;
- rejects stale asynchronous results;
- rechecks the online display set before installation;
- removes disconnected resources immediately;
- swaps the final backend set on the main actor;
- unregisters callbacks and observers at teardown.

This is a sound foundation. It directly addresses a major failure class in monitor utilities: stale work completing after wake, hot-plug, mode changes, or replacement sessions.

### Serialized DDC work

MyMonitor keeps IOAV service discovery, DDC reads, validation, writes, rematching, and invalidation on one serial queue. Slider writes are latest-value coalesced and obsolete generations are ignored.

This is conservative and correct as a baseline because the adapted IOAV transport has shared mutable service state and monitor firmware frequently behaves poorly under concurrent I²C traffic.

### Gamma ownership

Gamma control has a per-display owner token. Global ColorSync restoration is followed by replay of every still-owned Gamma or transition hold. This prevents a stale backend from brightening a replacement or another active display.

### Shade ownership

Shade windows are nonactivating, mouse-transparent, Space-aware, fullscreen auxiliary, explicitly torn down, and guarded against stale animation completions.

### Frontend boundary

The presentation layer does not enumerate displays, call DDC, choose fallback methods, or own hardware teardown. This boundary should be strengthened rather than replaced.

## 1.2 The most important semantic defect: attempted is treated as applied

`BrightnessBackend.setBrightness` returns no result. The router immediately updates its display state and, on committed changes, persists the value.

The model therefore conflates:

1. user intent;
2. queued or attempted hardware work;
3. confirmed monitor state.

A failed DDC write can leave the interface and persistence claiming a value the monitor never accepted. The next engine must represent desired, observed, and operation status separately.

## 1.3 Cold launch can overwrite hardware state

The current reconciliation order is:

1. live in-process value;
2. persisted value;
3. probed DDC value;
4. full brightness.

Backend construction then immediately applies the selected value.

On a cold launch, a saved value can therefore beat a newly read hardware value and cause an unsolicited brightness change. This violates the principle that discovery should observe before it mutates.

## 1.4 DDC capability validation performs a write

Current DDC probing:

1. reads VCP `0x10`;
2. writes the exact current value;
3. rereads and verifies it;
4. carries the validated service into the backend.

The write is intended to be visually neutral, but it remains a hardware command. Some monitors wake, switch internal state, delay, reject, or mishandle no-op writes. Capability discovery should be read-only by default; write capability can be established on the first explicit user command.

## 1.5 Durable identity is not durable

Preferences and known-display records are keyed by `CGDirectDisplayID`. That identifier is useful within a runtime topology but is not a sufficient durable identity across ports, docks, sessions, and some reconnects.

The imported IORegistry matcher already exposes richer evidence:

- EDID UUID;
- manufacturer and product name;
- numeric and alphanumeric serial;
- display location;
- upstream/downstream transport;
- service location.

The next design should preserve runtime IDs for live calls while moving persistence to a fingerprint and confidence model.

## 1.6 Apple-native brightness is absent

The active tier set is DDC, Gamma, and Shade. The bridging header already declares DisplayServices functions, but MyMonitor does not use them.

Apple displays and some natively connected displays may expose a macOS-native brightness path that is preferable to DDC. Lunar implements a distinct Apple-native controller using DisplayServices and CoreDisplay capability evidence.

The internal cascade should become Apple Native → DDC → Gamma → Shade while preserving the simpler user-facing vocabulary.

## 1.7 Gamma probing changes the transfer function

Current Gamma probing temporarily applies a `0.92` transfer multiplier and reads it back. Even though the engine restores ColorSync and replays active holds, capability discovery can still cause a visible flash or interfere with HDR, calibration, Night Shift, or another transfer-table owner.

Gamma should not be activated merely to prove it can be activated. The safer design captures the current per-display table, composes dimming from that baseline, and refuses the path when a baseline cannot be captured or restored safely.

## 1.8 Topology is read live throughout a generation

The current router calls Core Graphics and `NSScreen` in multiple methods while a reconfiguration unfolds. Full mirroring is inferred from a screen-count heuristic plus mirror-set membership.

The existing generation checks reduce stale installation, but a stronger design captures one immutable topology snapshot and resolves the entire generation from that snapshot.

## 1.9 Diagnostics describe state but not causality

Current diagnostics include app/OS metadata, connected state, brightness, allowed range, requested method, and active method. They do not explain:

- why a method was selected;
- how a service matched a display;
- which lifecycle reason started a generation;
- how long discovery took;
- whether a write was queued, attempted, verified, retried, or rejected;
- whether state is desired or observed;
- why fallback occurred.

The next diagnostic system should be structured, local, bounded, and privacy-scoped.

---

# 2. Apple platform constraints

## 2.1 Public topology and Gamma APIs exist

Apple documents public Core Graphics APIs for:

- display reconfiguration callbacks;
- online display enumeration;
- vendor, model, and serial values;
- transfer-function and transfer-table access;
- ColorSync restoration.

AppKit documents screen-parameter notifications. MyMonitor should use these public APIs as the outer topology and Gamma boundary.

Documentation pages:

- https://developer.apple.com/documentation/coregraphics/cgdisplayregisterreconfigurationcallback(_:_:)
- https://developer.apple.com/documentation/coregraphics/cggetonlinedisplaylist(_:_:_:)
- https://developer.apple.com/documentation/coregraphics/cgdisplayvendornumber(_:)
- https://developer.apple.com/documentation/coregraphics/cgdisplaymodelnumber(_:)
- https://developer.apple.com/documentation/coregraphics/cgdisplayserialnumber(_:)
- https://developer.apple.com/documentation/coregraphics/cggetdisplaytransferbytable(_:_:_:_:_:_:)
- https://developer.apple.com/documentation/coregraphics/cgsetdisplaytransferbytable(_:_:_:_:_:)
- https://developer.apple.com/documentation/coregraphics/cgdisplayrestorecolorsyncsettings()
- https://developer.apple.com/documentation/appkit/nsapplication/didchangescreenparametersnotification

These APIs do not provide a public general-purpose DDC/CI transport for third-party external displays.

## 2.2 Hardware control depends on undocumented interfaces

MyMonitor currently bridges:

- `IOAVServiceCreateWithService`;
- `IOAVServiceReadI2C`;
- `IOAVServiceWriteI2C`;
- `CoreDisplay_DisplayCreateInfoDictionary`;
- DisplayServices brightness functions.

These are not normal public SDK contracts. They can change across macOS releases and should be isolated behind a tiny adapter module with availability checks and explicit failure behavior.

## 2.3 Distribution consequence

Apple App Review Guideline 2.5.1 states that App Store apps may only use public APIs. Because MyMonitor’s useful external-display hardware paths rely on undocumented interfaces, the backend contract assumes direct distribution with Developer ID signing and notarization rather than promising Mac App Store eligibility.

This is a product and maintenance constraint, not permission to spread private symbols throughout the app.

Guideline:

- https://developer.apple.com/app-store/review/guidelines/#software-requirements

## 2.4 No privileged helper is justified

Brightness control currently requires no root process, kernel extension, DriverKit extension, Accessibility permission, Screen Recording permission, or Input Monitoring permission.

The backend contract rejects adding a privileged helper unless a future concrete control path proves that it is necessary, safer, and supportable. Complexity is not reliability.

---

# 3. DDC/CI and monitor behavior

## 3.1 VCP `0x10` is the relevant command

MyMonitor controls luminance through DDC/CI VCP code `0x10`. The command exposes a current and maximum value. The maximum is monitor-defined and must not be assumed to be 100.

The engine must normalize between the monitor’s actual range and MyMonitor’s `0...1` invariant.

## 3.2 Real monitors are inconsistent

In practice, monitors may:

- report a maximum other than 100;
- return a valid-looking read but reject writes;
- accept a write but apply it later;
- accept commands only on the active input;
- expose duplicate or ambiguous IORegistry services;
- reset brightness after sleep;
- lose their IOAV service across wake;
- stop responding temporarily after a mode or dock change;
- support DDC on one connection path but not another;
- expose two macOS displays for Picture-by-Picture while sharing one physical backlight.

The backend must model uncertainty and typed failure instead of reducing all of this to `Bool` or `nil`.

## 3.3 Read and write timing are different concerns

A slider needs low perceived latency, but DDC firmware often requires spacing and retries. The correct model is:

- immediate optimistic presentation;
- coalesced desired-state updates;
- serialized transport writes;
- final committed write;
- bounded verification or acknowledgement;
- no unbounded retry loop;
- no main-actor sleep.

## 3.4 Capability strings are evidence, not truth

MCCS capability strings can be absent or inaccurate. The first engine version does not require parsing them. A successful read is evidence that luminance is readable; the first explicit write and subsequent readback establish write health.

---

# 4. MonitorControl lessons

Source snapshot reviewed:

- https://github.com/MonitorControl/MonitorControl
- `MonitorControl/Support/Arm64DDC.swift`
- `MonitorControl/Model/OtherDisplay.swift`
- `MonitorControl/Model/Display.swift`

## 4.1 Useful patterns

MonitorControl demonstrates:

- Apple-silicon IOAV service matching;
- EDID, location, product, serial, and transport evidence;
- per-display DDC configuration and overrides;
- configurable polling and retry behavior;
- distinct software brightness behavior;
- per-display preference namespaces;
- the need for careful IORegistry object release.

MyMonitor already adapted and hardened part of this code, including allocation and object-lifetime fixes.

## 4.2 Patterns not to inherit wholesale

MonitorControl’s mature feature surface also contains years of configuration paths, startup modes, DDC command types, smoothing behavior, keyboard integration, and compatibility options. MyMonitor should not copy that surface.

The lesson is to build a small, explicit engine with typed state—not to reproduce every monitor-control preference.

## 4.3 Issue-history evidence

MonitorControl’s public issues repeatedly describe classes of failure involving:

- wake and sleep;
- lost brightness control after wake;
- brightness resetting or not restoring;
- crashes around connection changes;
- HDR interactions with software dimming;
- Picture-by-Picture values diverging;
- Apple-silicon service discovery.

These reports are hardware-specific anecdotes, not universal proofs. They nonetheless justify treating lifecycle, service identity, shared physical controls, and Gamma/HDR safety as first-class design areas.

Representative issues:

- https://github.com/MonitorControl/MonitorControl/issues/1648
- https://github.com/MonitorControl/MonitorControl/issues/1349
- https://github.com/MonitorControl/MonitorControl/issues/1398
- https://github.com/MonitorControl/MonitorControl/issues/1529
- https://github.com/MonitorControl/MonitorControl/issues/1552
- https://github.com/MonitorControl/MonitorControl/issues/873

---

# 5. Lunar lessons

Source snapshot reviewed:

- https://github.com/alin23/Lunar
- `Lunar/Control/AppleNativeControl.swift`
- `Lunar/DDC/DDC.swift`
- `Lunar/Data/Display.swift`

## 5.1 Apple-native control is a distinct method

Lunar treats Apple-native control separately from DDC and software dimming. It checks DisplayServices capability and can read/write through DisplayServices or CoreDisplay behavior.

MyMonitor should adopt the architectural lesson: Apple-native hardware control is its own internal session, not a special case hidden inside DDC.

## 5.2 Gamma needs baseline ownership

Lunar captures default Gamma tables and composes software brightness from stored transfer data. MyMonitor’s next Gamma engine should likewise preserve a per-display baseline rather than applying a generic formula and globally restoring ColorSync whenever possible.

## 5.3 Complexity accumulation is real

Lunar’s July 2026 changelog says its next major version rewrites the brightness engine to remove legacy workarounds accumulated over years. MyMonitor should take this as a warning to keep reasons, failures, state transitions, and compatibility exceptions explicit from the beginning.

Changelog snapshot:

- https://github.com/alin23/Lunar/commit/8a21ffe302a00890d9f5d5101536cdd2a4631be8

---

# 6. BetterDisplay lessons

Public project documentation reviewed:

- https://github.com/waydabber/BetterDisplay

BetterDisplay’s current documentation emphasizes:

- DDC auto-configuration;
- Apple and third-party hardware control;
- software and hardware methods;
- docks and dongles as compatibility variables;
- EDID and detailed display information;
- multi-display synchronization and groups;
- extensive HDR/XDR and display-configuration scope.

The useful backend lesson is that connection path, EDID, control capability, and hardware topology are separate dimensions. The product lesson is the opposite: MyMonitor should not expand into resolution, virtual displays, HDR boosting, network TV control, input switching, or general display configuration.

---

# 7. Adopted conclusions

The contract adopts these conclusions:

1. Preserve the current generation-safe and teardown-safe foundation.
2. Introduce desired, observed, and write-status state.
3. Make discovery read-only by default.
4. Replace `force: Bool` policy with typed lifecycle reasons.
5. Build durable fingerprint identity with confidence and duplicate handling.
6. Add Apple-native control ahead of DDC in the internal cascade.
7. Isolate undocumented interfaces in `PrivateDisplayKit`.
8. Put DDC behind an injectable transport and typed failures.
9. Keep global serialization initially, then permit per-transport lanes only after evidence.
10. Replace destructive Gamma probing with lazy, baseline-preserving activation.
11. Resolve every generation from an immutable topology snapshot.
12. Add structured, bounded, local diagnostics.
13. Treat hardware qualification as a release gate.
14. Reject server infrastructure, privileged helpers, and broad display-tool scope.

# 8. Open research questions

These remain implementation spikes, not unresolved product semantics:

- Which public and private identity fields remain stable across direct cable, dock, and port changes on macOS 26?
- Which Apple external displays respond reliably to DisplayServices on current hardware?
- Can an IOAV service be safely used from independent per-service queues, or must all services remain globally serialized?
- Which HDR/EDR states make transfer-table Gamma unavailable or unsafe?
- How should two physically identical, zero-serial displays be distinguished when their connection paths swap?
- Which monitors require longer DDC delays or multiple write cycles, and can adaptive timing be learned without exposing settings?
- Which Picture-by-Picture monitors expose two logical displays backed by one physical luminance control?

Each question has a bounded spike in `IMPLEMENTATION_PLAN.md`; none justifies speculative infrastructure in B1.