# Backend Edge-Case Acceptance Contract

Status: **Canonical specification supplement**  
Applies to: **B2, B8, B10, B11**  
Decisions: **B-D031, B-D033, B-D034, B-D036, B-D037**

This file binds two transitions that must not be left to implementation judgment:

1. relative brightness commands after validation or writing has failed;
2. automatic replacement between control domains after an earlier explicit preference selection.

## Relative-command eligibility

A relative command may reach a control method only when the active session has one of:

- a current evidence-backed observation;
- a confirmed continuity target in the active domain;
- an absolute value selected in the current process whose write path has not subsequently failed.

An unconfirmed persisted seed is presentation state, not a relative-command baseline.

When no eligible baseline exists:

1. perform at most one non-mutating refresh for that command generation;
2. use a new observation when available;
3. otherwise return `baselineUnavailableForRelativeAdjustment`;
4. perform zero brightness writes;
5. keep absolute slider selection available.

### First absolute write

An absolute selection may open one serialized validation gate:

- one latest value owns validation;
- newer pointer values replace one pending catch-up/final value;
- no more than one validation plus one newest catch-up/final operation reaches the resource;
- stale validation cannot publish over newer intent.

### Failure suspension

After validation or a later write fails:

- cancel pending catch-up work;
- preserve desired/presented intent when useful;
- suspend relative-command transport eligibility for that baseline;
- repeated hotkeys perform zero writes;
- do not silently switch methods inside the failed operation.

Eligibility returns only through:

- fresh evidence-backed observation;
- successful explicit Retry; or
- a new absolute user selection opening one new serialized gate.

A hotkey alone never reopens validation.

## Explicit selection versus automatic replacement

An explicit preference selection and a later automatic replacement are different authorization events.

### Explicit selection transaction

The method chosen while the user selects Automatic, Hardware control, Software control, or Display shade may apply **its own domain's** saved value after neutral installation and ownership validation.

This authorization belongs to the method/domain chosen during that transaction. It is not perpetual permission for another future method in the same broad family.

### Later automatic replacement

A replacement caused by health, wake, topology, mode, capability, or resource change is automatic even when the stored preference remains Software control or Automatic.

When it crosses domains:

- install the target method at neutral;
- preserve, but do not apply, the target domain's saved value;
- never copy the source domain's normalized value;
- neutralize the old software owner before another software domain becomes non-neutral;
- require Retry, preference reselection, direct method selection, or a new absolute command before applying preserved target-domain intent.

## Required deterministic traces

### Repeated hotkeys after failed validation

Fixture: first-write validation fails, then ten relative commands arrive.

Assert:

- only the original validation reached the resource;
- pending catch-up was cancelled;
- all ten commands produce zero writes;
- observed and continuity state remain unchanged;
- successful Retry opens at most one new validation gate.

### New absolute selection after failure

Assert:

- one new validation gate opens;
- drag values coalesce into one newest catch-up/final value;
- relative commands cannot create concurrent gates;
- success restores eligibility from evidence;
- failure suspends it again.

### Explicit Software selection resolves Shade

Fixture: Gamma is unsafe before the user selects Software control and a saved Shade value exists.

Assert:

- only Gamma and Shade are considered;
- Shade may apply its own saved value as part of this explicit transaction;
- Gamma and hardware values are not copied.

### Later Gamma-to-Shade replacement

Fixture: Gamma is active, Software remains selected, a saved Shade value exists, and a later mode change makes Gamma unsafe.

Assert:

- replacement is automatic;
- Shade installs neutral;
- saved Shade intent remains persisted but unapplied;
- Gamma and Shade are never simultaneously permanently non-neutral;
- explicit Retry or reselection may later authorize Shade convergence.

### Automatic hardware-to-software replacement

Fixture: Automatic uses hardware at `0.35`, hardware disappears, and Gamma is safe.

Assert:

- Gamma installs neutral;
- hardware `0.35` is not replayed as Gamma `0.35`;
- no uncertain hardware operation is stacked with Gamma;
- a later absolute adjustment establishes Gamma-domain intent.

## Diagnostics and completion gate

Diagnostics record the trigger as explicit or automatic, old/new method and domain, baseline eligibility, validation/catch-up identifiers, preserved-value disposition, neutralization, rollback, and suppressed zero-write relative commands.

B11 is incomplete until these traces pass under deterministic clocks/transports and applicable hardware checks are recorded. Changing these rules requires a decision update, migration analysis, revised traces, and explicit double-dimming/repeated-write analysis.
