# Backend QA and Hardware Qualification Matrix

This matrix separates what can be proven automatically from what requires platform adapters and physical displays. A release candidate is not backend-qualified until required hardware rows have recorded evidence.

## 1. Result vocabulary

- **Pass** — observed behavior satisfies every acceptance condition.
- **Fail** — reproducible violation with issue/trace reference.
- **Blocked** — required equipment or OS environment unavailable.
- **Not applicable** — row does not apply to the release’s claimed support.
- **Exploratory** — evidence collected but not a release claim.

Every hardware result records:

- date;
- MyMonitor commit/build;
- macOS version/build;
- Mac model family and chip;
- monitor make/model;
- connection path including dock/adapter;
- topology/mirror/HDR state;
- requested and active method;
- pass/fail evidence;
- privacy-safe diagnostic export when failed.

Do not record monitor serial numbers in committed test results.

---

# 2. Automated policy matrix

| Area | Scenario | Expected |
|---|---|---|
| Brightness | Normalize below 0 / above 1 | Clamp to `0...1` |
| Brightness | Configured range 0.2...0.8 | Every desired value clamps before method conversion |
| State | Write queued | Desired changes; observed does not |
| State | Transport accepts, no trustworthy readback | Status is accepted-unverified; observed and continuity target do not change |
| State | Write succeeds with evidence | Status is applied; observed updates with source/time |
| State | Write fails | Desired remains; observed remains prior value; failure visible |
| State | Older write finishes after newer write | Older result is ignored |
| State | Failure then fresh observation | Failure clears only through explicit reducer rule |
| Launch | Saved 30%, hardware reads 70% | Cold launch presents/adopts 70%, performs zero writes |
| Launch | Hardware unreadable, saved 30% | Present selected-domain desired 30% as unconfirmed; no launch write |
| Relative | Only baseline is an unconfirmed persisted seed | One refresh attempt, then typed failure and zero writes |
| Relative | User made an absolute selection this process | Selection becomes process-local adjustment baseline |
| First write | Drag continues while validation runs | At most one validation and one newest catch-up/final operation |
| Wake | Pre-sleep probe completes after wake event | Result rejected |
| Wake | Confirmed session, monitor reset | One bounded restore attempt per continuity/wake epoch |
| Wake | Repeated callbacks create multiple generations | Generations reject stale publication; restore budget remains consumed for the epoch |
| Wake | Identity confidence falls | Adopt/read; do not auto-restore |
| Reconnect | High-confidence transient continuity | Confirmed continuity target may carry forward; unverified desired intent may not |
| Reconnect | No continuity evidence | Observe/adopt before write |
| Topology | Callback burst | One settled generation after quiet window |
| Topology | Continuous events | Maximum deadline prevents indefinite delay |
| Topology | Disconnect during write | Resource invalidates; late result ignored |
| Mirror | Full mirror | One logical representative/group |
| Mirror | Partial mirror + extended display | Unrelated display remains visible |
| Group | One member fails | Group is not falsely all-applied |
| Identity | Exact nonzero serial | Exact profile match |
| Identity | Exact EDID digest | Exact/high profile match |
| Identity | Serial zero | Serial ignored |
| Identity | Two indistinguishable monitors | Ambiguous/connection-bound; no silent merge |
| Identity | One profile, two runtime candidates | Global assignment prevents duplicate use |
| Migration | Run v2 migration twice | Same v3 result; no duplicate profile |
| Migration | Ambiguous legacy record | Legacy data preserved and not consumed |
| Forget | Connected known display | Profile/legacy/hotkey references removed; physical brightness unchanged |
| Resolver | Automatic compatible native display | Apple Native first |
| Resolver | Explicit Hardware, no hardware method | Unavailable; no Gamma/Shade fallback |
| Resolver | Explicit Software, Gamma unsafe, Shade available | Shade selected; no Native/DDC fallback |
| Resolver | Explicit Software, no software method | Unavailable; no hardware fallback |
| Resolver | Native absent, DDC readable | DDC selected |
| Resolver | Hardware absent, Gamma safe | Gamma selected |
| Resolver | Gamma unsafe | Shade selected |
| Resolver | DDC operation uncertain | No inline second-method dimming |
| Transition | Hardware to Gamma automatic fallback | Gamma begins neutral; hardware numeric desired is not replayed |
| Transition | Gamma to Shade | Never simultaneously non-neutral; rollback is explicit |
| Transition | Apple Native to DDC | Confirmed hardware-domain target may transfer after compatible observation |
| DDC | Maximum 255, current 128 | Normalize using 255, not 100 |
| DDC | Maximum zero | Typed invalid-range failure |
| DDC | Invalid checksum | Typed checksum failure; no observed update |
| DDC | Stale service | One rematch of newest operation |
| DDC | Repeated stale service | Degraded after bounded attempts |
| DDC | Rapid 100 updates | Coalesces; final committed value wins |
| DDC | Verification mismatch | Desired/observed differ; degraded |
| Gamma | Baseline composition | Channels remain monotonic and proportional |
| Gamma | Stale owner teardown | New owner remains applied |
| Gamma | Wake/mode change | Baseline invalidated and recaptured |
| Gamma | Unsafe HDR fixture | Gamma excluded |
| Shade | Older animation completion | Cannot hide/show newer state |
| Shade | Screen mapping removed | Recovering/unavailable; no stale applied claim |
| Diagnostics | Raw serial/EDID/path injected | Export contains none |
| Diagnostics | Ring exceeds limits | Oldest events evicted |
| Diagnostics | Recorder fails | Brightness control unaffected |
| Teardown | Called twice | Idempotent |
| Teardown | Callback after termination | No work/state publication |

---

# 3. Fake-transport integration traces

Required deterministic traces:

## 3.1 Cold launch

- one DDC-readable display;
- one saved profile with different desired value;
- assert no write;
- assert observed hardware is adopted.

## 3.2 Wake with stale service

- active DDC session;
- wake event;
- old service write completion arrives;
- repeated reconfiguration callbacks create multiple engine generations inside the same wake epoch;
- new topology/service captured;
- confirmed continuity target restored once when continuity permits;
- assert later generations do not trigger another restore attempt;
- old completion ignored.

## 3.3 First-write validation during drag

- selected hardware method is readable but write-unvalidated;
- user drags through many values;
- one validation operation starts with the latest eligible value;
- newer values replace one pending catch-up target;
- release commits the final value;
- assert no more than one validation plus one newest catch-up/final write;
- failure cancels catch-up and publishes no observed state.

## 3.4 Drag during reconfiguration

- cached session visible;
- user drags while discovery is running;
- final discovery result contains older observed value;
- live desired wins presentation;
- final operation verifies independently.

## 3.5 Hot-unplug during debounce

- disconnect event;
- row/resource removed immediately;
- expensive reprobe delayed;
- queued transport work invalidated.

## 3.6 Shared physical resource

- two runtime displays map to one service;
- one transport lane created;
- concurrent intents serialize/coalesce according to group policy;
- no duplicate writer.

## 3.7 Ambiguous identity

- two identical saved profiles;
- two identical runtime displays with swapped connection paths;
- global assignment returns low/ambiguous evidence;
- no automatic restore from wrong profile.

## 3.8 DDC write uncertainty

- write call reports timeout but simulated hardware later reads requested value;
- no immediate Gamma/Shade stacking;
- verification can reconcile applied result.

## 3.9 Teardown race

- write, verification, topology timer, and diagnostic save in flight;
- terminate;
- release resources;
- late events publish nothing.

## 3.10 Cross-domain transition

- hardware domain has confirmed desired 0.35;
- Automatic loses hardware capability and selects Gamma;
- Gamma installs at neutral rather than replaying 0.35;
- no simultaneous hardware write and Gamma dimming represents one command;
- explicit Software selection may later apply the saved Gamma-domain value;
- rollback leaves one truthful active owner.

## 3.11 Relative adjustment without baseline

- hardware is unreadable;
- profile contains only an unconfirmed saved seed;
- hotkey increment triggers one non-mutating refresh;
- refresh remains unreadable;
- assert zero writes and typed actionable failure;
- absolute slider selection may enter first-write validation.

## 3.12 Terminal teardown

- DDC actor, verification timer, and discovery are in flight;
- Gamma and Shade resources are owned;
- synchronous terminal boundary invalidates publication and restores/closes main-thread resources;
- termination does not await DDC actor completion;
- late actor results publish nothing.

---

# 4. Static and build gates

Every backend PR:

- `swift test -Xswiftc -warnings-as-errors`;
- frontend contract script;
- backend contract script;
- generated project drift check;
- arm64 Debug build with warnings as errors;
- arm64 Release build with warnings as errors;
- `git diff --check`;
- no new runtime dependency without decision record;
- no undocumented declaration/call outside approved adapter boundary;
- no `sleep`/`usleep` in engine or main-actor code;
- no raw `CGDirectDisplayID` persistence key in new profile code;
- no observed-state update on write enqueue;
- no unbounded collection, retry, or timer;
- no network framework/import in core backend targets.

---

# 5. Required physical hardware matrix

## 5.1 Mac hosts

At minimum, before first public release:

| Host | Required |
|---|---:|
| Base Apple-silicon MacBook with USB-C/Thunderbolt | Yes |
| Apple-silicon desktop or second Mac family | Yes when available |
| Built-in HDMI Apple-silicon Mac | Strongly recommended |
| Intel Mac | No; product target is Apple silicon |

## 5.2 Connection paths

| Path | Required |
|---|---:|
| USB-C to USB-C direct | Yes |
| USB-C to DisplayPort direct | Yes |
| HDMI direct/built-in port | Yes when host available |
| USB-C HDMI adapter | Yes |
| Thunderbolt/USB-C dock DisplayPort | Yes |
| Thunderbolt/USB-C dock HDMI | Yes |
| Known DDC-blocking dongle | Yes as fallback test |
| DisplayLink/virtual graphics path | Exploratory; no support claim by default |

## 5.3 Monitor classes

| Class | Required |
|---|---:|
| Common third-party DDC monitor | Yes |
| Monitor reporting max != 100 | Strongly recommended |
| Monitor with unreliable DDC read/write | Strongly recommended |
| Apple Studio Display or compatible Apple Native display | Required for Apple Native claim |
| LG UltraFine/native compatible display | Recommended |
| HDR external display | Yes for Gamma safety |
| Two identical monitors | Yes for identity claim |
| PBP/PIP monitor exposing two logical displays | Recommended before shared-control claim |
| Non-DDC monitor/blocked path | Yes for Gamma/Shade fallback |

## 5.4 Topologies

- one external, lid open;
- one external, clamshell where applicable;
- two extended externals;
- three externals when host supports it;
- full mirror built-in + external;
- full mirror external + external;
- partial mirror plus one extended display;
- portrait/landscape arrangement;
- fullscreen Space on shaded display;
- multiple Spaces;
- main-display change;
- resolution/refresh-rate change;
- HDR toggle;
- PBP/PIP when available.

---

# 6. Per-method hardware acceptance

## 6.1 Apple Native

For each qualified monitor/path:

- cold launch reads without visible brightness change;
- slider changes correct display;
- final value readback is within tolerance;
- rapid drag remains responsive;
- wake reacquires and restores only as specified;
- reconnect does not apply stale profile unexpectedly;
- method switch to/from DDC/Gamma/Shade is safe;
- app quit leaves expected physical state;
- no built-in display is unintentionally changed.

## 6.2 DDC

- service matches intended display;
- no cold-launch write;
- first explicit write establishes health;
- actual maximum used;
- rapid drag coalesces without reverse/stale jumps;
- final value verifies or truthfully reports uncertainty;
- wake first write is not dropped;
- stale service rematches once;
- disconnect cancels queued writes;
- two displays remain independently responsive;
- adapter/dock unsupported path falls back truthfully;
- monitor menu/manual brightness changes are observed on next explicit refresh where supported;
- zero configured brightness remains recoverable.

## 6.3 Gamma

- no discovery flash;
- baseline capture succeeds before activation;
- dimming preserves color relationships visually;
- changing color profile/Night Shift does not leave a stale curve;
- HDR unsafe state excludes Gamma;
- two Gamma displays preserve each other;
- mirror/Space transitions do not leak holds;
- quit restores baseline;
- crash/relaunch recovery behavior is documented and tested as far as platform permits.

## 6.4 Shade

- window maps to intended display;
- mouse events pass through;
- no Dock/app activation side effect;
- all Spaces behavior matches contract;
- fullscreen content remains dimmed where intended;
- rapid animation changes do not hide a newer dim state;
- topology changes resize/remap correctly;
- mirror group behavior is correct;
- screenshot and screen-sharing behavior matches the recorded decision;
- quit removes every Shade window.

---

# 7. Lifecycle stress suite

Run each applicable method through:

1. 20 sleep/wake cycles.
2. 20 cable disconnect/reconnect cycles.
3. 20 dock disconnect/reconnect cycles.
4. 20 mirror/unmirror cycles.
5. 20 resolution or refresh-rate changes.
6. 5 minutes of continuous slider dragging.
7. Repeated Retry during discovery.
8. Method changes during discovery.
9. Quit during an in-flight write.
10. Launch immediately after forced termination.

Acceptance:

- no crash;
- no main-thread hang;
- no orphan Shade window;
- no unreleased Gamma dimming after normal quit;
- no stale row resurrection;
- no write to disconnected resource after invalidation;
- no unbounded memory/event growth;
- failures remain diagnosable.

---

# 8. Performance measurements

Measure in release configuration:

- menu-bar click to popover visible;
- topology event to cached recovering state;
- topology quiet to discovery start;
- service discovery duration;
- DDC read/write/verification duration;
- slider event to presented-state update;
- main-thread stalls over 16 ms during interaction;
- memory before/after 100 topology generations;
- resource count before/after 100 service discoveries;
- diagnostics encoded size at retention limit.

Initial budgets:

- presentation update: same main-actor turn;
- no synchronous hardware wait on main actor;
- no leaked IORegistry object over repeated discovery;
- bounded diagnostics at configured size;
- no monotonic memory growth in stress suite.

Hardware latency budgets are recorded by class rather than using one unrealistic universal number.

---

# 9. Distribution validation

Before public binary release:

- clean Release archive;
- Developer ID signature valid;
- hardened runtime valid;
- notarization accepted;
- ticket stapled;
- `spctl` Gatekeeper assessment accepted;
- launch from `/Applications` on a clean test account;
- launch-at-login consent behavior verified;
- no quarantine-removal script or instruction;
- license and third-party notices bundled;
- privacy statement matches actual behavior;
- update mechanism, if later added, receives a separate security review.

---

# 10. Release-blocking failures

Always block release:

- cold-launch unexpected brightness write;
- wrong-display hardware write;
- unbounded retry/hang;
- stale operation overwrites newer user intent;
- app quit leaves Shade or owned Gamma state behind in qualified scenarios;
- identity ambiguity restores another display’s profile;
- raw serial/EDID/path in support export;
- crash on ordinary wake/hot-plug;
- no deterministic recovery from a black Shade state;
- unsigned/unnotarized public build presented as production-ready.

May ship as documented limitation only after explicit decision:

- one unsupported adapter path;
- one monitor with unreliable readback using lower-confidence write-only state;
- unavailable Apple Native hardware for qualification;
- PBP grouping not yet supported;
- Gamma disabled in HDR.
