# Frontend Implementation Plan

The frontend is implemented one small pull request at a time. This sequence deliberately separates presentation architecture, surface anatomy, Settings, accessibility, and final backend integration.

## Execution protocol

Before each ticket:

1. Read every document in `docs/frontend/`.
2. Read all files that will be changed.
3. Confirm the ticket's prerequisites are merged.
4. Do not implement later-ticket behavior opportunistically.

After each ticket:

1. Regenerate the project.
2. Build with Xcode 26.
3. Run automated tests added by the ticket.
4. Complete the ticket's manual QA matrix.
5. Report files changed, rationale, commands, results, known limitations, and the next ticket.

Every ticket must leave the app buildable. UI hidden behind placeholders does not count as complete.

## Architecture target

```text
App lifecycle (AppKit/SwiftUI boundary)
├── StatusItemController
├── PopoverCoordinator
├── SettingsWindowCoordinator
└── PresentationStore (@MainActor, observable)
    ├── DisplayPresentationState
    ├── MonitorPresentation models
    └── user intents
        └── MonitorControlling protocol
            └── existing DisplayRouter adapter
```

Names are illustrative. Responsibilities are binding.

### Views may

- Render immutable/observable presentation state.
- Format user-facing values.
- Maintain ephemeral focus/disclosure state.
- Emit intent: set brightness, retry, refresh, open Settings, quit.

### Views may not

- Enumerate displays.
- Probe DDC/gamma/overlay.
- Choose control tiers.
- Perform hardware writes.
- Own write debouncing.
- Construct backend services.
- Read/write persistence keys directly.
- Observe workspace/display notifications directly.

### Presentation store may

- Convert backend state into explicit user-facing state.
- Keep optimistic slider values stable while writes occur.
- Coordinate display snapshots and errors.
- Expose deterministic fixture construction for previews/tests.

### Backend adapter may

- Translate existing `DisplayRouter` behavior into the frontend protocol.
- Preserve existing hardware behavior until later backend-specific work.

## Ticket F0 — Specification baseline

**Goal:** Land this documentation suite.

Changes:

- Add canonical frontend contract.
- Add research, product, design, implementation, QA, and decision documents.
- Link the contract from the root README.

Acceptance:

- Documentation is internally consistent.
- No production behavior changes.
- Existing Xcode build passes.

## Ticket F1 — Presentation-state seam

**Goal:** Make the UI testable without hardware and remove backend knowledge from views.

Changes:

- Define explicit presentation state and monitor presentation models.
- Define a small monitor-control intent protocol.
- Add an adapter around current `DisplayRouter`.
- Add deterministic fixtures for every popover state.
- Keep current UI appearance temporarily.

Tests:

- Backend states map to expected user-facing method/status.
- Brightness values clamp and format correctly.
- Stable row ordering and mirrored-display presentation are deterministic.
- An optimistic slider value is not overwritten by a stale backend snapshot.

Manual QA:

- Existing brightness control still works on real hardware.
- No visual redesign in this ticket.

Non-goals:

- Settings.
- New popover layout.
- Backend refactor beyond the adapter seam.

## Ticket F2 — Native surface spike

**Goal:** Decide the exact native host for the popover and Settings window with evidence.

Prototype A:

- Existing `NSStatusItem` + transient `NSPopover`.

Prototype B, only if practical:

- SwiftUI `MenuBarExtra` with window style and Settings scene.

Measure:

- Correct anchor on multiple menu bars/displays.
- Click-to-visible latency.
- Escape/outside-click dismissal.
- Keyboard focus on first slider.
- Opening/focusing Settings.
- Fullscreen Space behavior.
- Duplicate-window/popover behavior.

Deliverable:

- Update `DECISIONS.md` with selected host and rejected alternative.
- Keep only the selected production path.

Acceptance:

- The selected host meets all measured behaviors.
- No custom floating `NSPanel` is introduced.

## Ticket F3 — Popover shell and footer

**Goal:** Implement the native shell before monitor-row polish.

Changes:

- Status item uses `display` template symbol.
- Content-driven native popover width/height.
- Root background remains system-managed.
- Add stationary footer with `Preferences…` and `Quit`.
- Add one divider above footer.
- Ensure one Settings window instance.

Fixture content:

- Temporary plain text display rows only; do not implement final row here.

Acceptance:

- Correct anchor and transient dismissal.
- No custom background, shadow, border, or entrance animation.
- Preferences opens/focuses Settings.
- Quit performs orderly teardown.
- Keyboard reaches footer actions.

## Ticket F4 — Native monitor row

**Goal:** Implement the primary control using standard components.

Changes:

- Display-name/percentage header.
- Native slider with moon/sun symbols.
- Control-method status line.
- Optimistic brightness interaction through presentation store.
- VoiceOver label/value/hint.

Tests:

- 0 is darkest and 1 is brightest.
- Percentage formatting uses whole numbers and monospaced digits.
- Final value persists only on commit/release according to intent contract.
- Failure state does not reverse or silently revert the UI.

Manual QA:

- Pointer drag.
- Arrow-key adjustment.
- Focus ring.
- VoiceOver adjustable action.
- Light, Dark, Graphite, non-blue accent.

Non-goals:

- Multiple-row scrolling.
- Settings display configuration.

## Ticket F5 — Popover state completeness

**Goal:** Implement every non-happy-path state in `PRODUCT_SPEC.md`.

Changes:

- Detecting state.
- No-display empty state and Refresh.
- Checking-method status.
- Software/shade fallback status and info disclosure.
- Unavailable control state with Retry and Open Diagnostics.
- Display connection/disconnection transitions.

Tests:

- State transitions are explicit and deterministic.
- Retry affects only the intended display.
- Last-display removal produces empty state.
- No infinite progress state.

Manual QA:

- Reduce Motion.
- Reduce Transparency.
- Increased Contrast.
- Long error/localized strings.

## Ticket F6 — Multi-monitor layout

**Goal:** Make two through many displays stable and understandable.

Changes:

- Conditional `Displays` heading for two or more rows.
- Stable display ordering.
- Mirrored-set presentation.
- Scroll region when content exceeds maximum height.
- Stationary footer.
- Long-name truncation behavior.

Tests:

- Fixtures for 1, 2, 4, and 8 displays.
- Stable ordering across snapshots.
- Footer remains outside scrolling content.
- Correct focus traversal through all rows.

Manual QA:

- Two physical external displays.
- Menu bar on secondary display.
- Mixed DDC/fallback methods.

## Ticket F7 — Settings window shell

**Goal:** Build the real Mac Settings anatomy with no fake controls.

Changes:

- Standard window chrome.
- One instance, default/minimum sizes, restoration.
- Native inset sidebar/detail layout.
- Sections: General, Displays, Advanced, About.
- Keyboard section remains hidden until ticket F10 adds behavior.
- Each section initially contains only implemented content or a concise status summary; no disabled placeholders.

Acceptance:

- Resize from minimum to large width without clipping/stretching.
- Native sidebar selection/focus.
- Closing Settings leaves app running.
- Reopening focuses existing window.
- Active/inactive window appearances are correct.

## Ticket F8 — General settings

**Goal:** Add only real global preferences.

Changes:

- `Launch MyMonitor at login` backed by actual system registration.
- `Show brightness percentage` only if product testing confirms the preference is worth keeping; otherwise omit it.
- Display order picker only if supported by presentation store.

Tests:

- Launch-at-login UI reflects actual system status and errors.
- Preferences persist and update current UI where applicable.

Manual QA:

- Register/unregister login item.
- Relaunch app and Settings.
- Failure/retry path.

## Ticket F9 — Displays settings

**Goal:** Add per-display configuration without leaking backend internals.

Changes:

- Connected and remembered display list.
- Display detail.
- Minimum/maximum brightness.
- Automatic/control-method picker.
- Forget display settings.

Tests:

- Minimum never exceeds maximum.
- Opening Settings never changes physical brightness.
- Current value clamps only after explicit user intent.
- Unsupported method has clear disabled/explanatory state.
- Forget removes only that display's saved configuration.

Manual QA:

- Connected, disconnected remembered, and renamed displays.
- DDC and fallback display.

## Ticket F10 — Keyboard behavior and settings

**Goal:** Add familiar keyboard control as an independent feature slice.

Prerequisite:

- Research and select the least-permission system-compatible shortcut approach.

Changes:

- Brightness-key enablement.
- Target-display behavior.
- Optional custom increase/decrease shortcuts.
- Native-compatible shortcut recorder and conflict feedback.
- Keyboard Settings section becomes visible.

Tests:

- Target resolution for display under pointer/all/specific display.
- Shortcut conflict and clearing.
- No accidental handling while recording a shortcut.

Manual QA:

- Built-in keyboard, external keyboard, multiple displays.
- No unnecessary Accessibility/Screen Recording request.

## Ticket F11 — Advanced diagnostics

**Goal:** Make failures supportable without exposing complexity in the popover.

Changes:

- Re-detect displays.
- Retry hardware control.
- Copy diagnostic summary.
- Export diagnostic report.
- Reset all display preferences with confirmation.
- Deep link from popover error to relevant display diagnostics.

Tests:

- Export contains approved fields only.
- No window titles, clipboard, file paths, or unrelated inventory.
- Reset confirmation and scope.
- Retry preserves current visible brightness.

## Ticket F12 — About and attribution

**Goal:** Complete the small informational surface.

Changes:

- App name/icon.
- Version/build.
- One-sentence product description.
- Source link.
- Licenses and MonitorControl attribution.
- Privacy statement.

Acceptance:

- No marketing hero, web content, purchase, social, or update placeholder.
- Links open safely in default browser.

## Ticket F13 — Accessibility and localization hardening

**Goal:** Validate the complete frontend as an accessible Mac app.

Changes:

- Audit all labels, values, hints, traits, focus order, announcements.
- Add localization catalog/resources.
- Fix text expansion and long display names.
- Ensure decorative symbols are hidden.
- Ensure state is never color-only.

Tests:

- Accessibility identifier/label tests for core controls where practical.
- Pseudolocalized/expanded-string fixtures.

Manual QA:

- Full VoiceOver path through popover and Settings.
- Keyboard-only path.
- Differentiate Without Color.
- Increased Contrast.
- Reduce Transparency.
- Reduce Motion.

## Ticket F14 — Visual regression and performance gate

**Goal:** Turn polish from opinion into a repeatable release gate.

Changes:

- Deterministic screenshot harness/previews for required states.
- Instrument click-to-visible and slider visual response.
- Remove any remaining arbitrary visual customization.
- Audit main-thread work performed when opening popover/Settings.

Acceptance:

- All rows in `QA_MATRIX.md` pass.
- No popover-open DDC probe or display enumeration on the main thread.
- No visible layout jump on open.
- Required screenshots approved in all appearances.

## Ticket F15 — Backend integration refinement

**Goal:** Revisit backend behavior only after the frontend contract is stable.

Potential work:

- Move probing/writes off the main actor.
- Improve current-brightness reads and acknowledgement semantics.
- Stabilize hot-plug/wake state delivery.
- Expose capability/error data required by the presentation model.

This ticket must not redesign UI. It makes the established frontend truthful and faster.

## Pull-request sizing rules

- Prefer 1–6 production files plus focused tests per ticket.
- A PR over roughly 800 changed production lines requires justification or decomposition.
- Generated Xcode project changes do not justify unrelated source changes.
- Do not mix documentation redesign, UI implementation, and backend refactor unless the ticket explicitly requires all three.

## Ticket completion template

```markdown
## Ticket
F# — Title

## User-visible change
...

## Files changed
- `path`: why

## Tests
- command/result

## Manual QA
- [ ] state/appearance/device

## Specification deviations
None, or link to the decision update.

## Known limitations
...

## Next ticket
F# — Title
```

## Stop conditions

Stop implementation and resolve the design/architecture question when:

- A native component cannot meet a binding requirement.
- A change requires a new privacy permission.
- A custom material/control appears necessary.
- A backend limitation would force misleading UI.
- A ticket would expose unfinished controls.
- A proposed change expands product scope.

Do not paper over these conditions with a temporary fake UI.
