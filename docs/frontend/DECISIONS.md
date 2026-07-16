# Frontend Decisions

This document records binding product and design decisions for MyMonitor's frontend. It prevents future implementation work from reopening settled questions without evidence.

A decision may be changed only by a pull request that:

1. Identifies the user problem or platform change.
2. Provides prototype or test evidence.
3. Updates every affected frontend document.
4. Explains migration and accessibility implications.

## D-001 — MyMonitor is monitor-only

**Status:** Accepted  
**Decision:** MyMonitor controls external monitors. It is not a generic menu-bar utility suite.

Included product area:

- External-display discovery.
- Per-display brightness.
- Automatic hardware/software/shade control selection.
- Display-specific configuration.
- Keyboard control.
- Recovery and diagnostics.

Excluded product area:

- Window management.
- Clipboard history.
- System monitoring.
- Disk cleaning.
- App launching.
- Accounts, subscriptions, analytics, cloud sync, or marketing surfaces.

**Rationale:** A narrow product can make the frequent monitor-control path immediate, reliable, understandable, and testable. Unrelated features increase permissions, state, navigation, failure modes, and visual density without improving the core job.

## D-002 — The interface inherits macOS instead of imitating it

**Status:** Accepted  
**Decision:** Use system components, semantic styles, SF Symbols, native focus, native window behavior, and the user's system appearance/accent whenever a correct platform component exists.

**Rejected:** A bespoke visual component library that redraws controls to resemble macOS.

**Rationale:** Native components provide behavior, accessibility, appearance adaptation, keyboard interaction, future OS styling, and reduced maintenance. A visually similar custom control is not functionally equivalent.

## D-003 — Liquid Glass is the control/navigation layer

**Status:** Accepted  
**Decision:** The popover, window, sidebar, menus, and system controls receive the platform's Liquid Glass treatment. Ordinary monitor rows and form content do not become nested glass cards.

**Prohibited by default:**

- Glass-on-glass.
- Custom blur layers.
- Translucent borders around every group.
- Fixed dark panels.
- Clear glass.
- Material effects used only as decoration.

**Rationale:** Apple positions Liquid Glass as a functional layer above content and advises against applying it to content or stacking it. Restraint preserves hierarchy and lets the system adapt to accessibility settings.

## D-004 — Two primary surfaces only

**Status:** Accepted  
**Decision:** The product has:

1. A menu-bar popover for frequent brightness control.
2. A Settings window for infrequent configuration and diagnostics.

**Rejected:** Onboarding carousel, dashboard, persistent main window, upgrade screen, and separate feature windows.

**Rationale:** Every additional primary surface adds navigation and state before the user can complete the one frequent task.

## D-005 — Use `NSStatusItem` and a transient `NSPopover` as the baseline

**Status:** Accepted as baseline; evidence spike permitted  
**Decision:** Continue with the current `NSStatusItem` plus native transient `NSPopover` architecture unless ticket F2 demonstrates that `MenuBarExtra` measurably improves required behavior without regressions.

F2 must compare:

- Correct anchoring on multiple displays/menu bars.
- Click-to-visible latency.
- Keyboard focus.
- Escape/outside-click dismissal.
- Fullscreen Space behavior.
- Settings-window coordination.
- Duplicate/stale surface behavior.

**Rejected:** Returning to a custom floating `NSPanel` for the main surface.

**Rationale:** `NSPopover` already supplies the required source relationship, transient lifecycle, system material, shadow, focus, and dismissal behavior. Architecture may change only for measured benefit.

## D-006 — All presented displays are directly visible

**Status:** Accepted  
**Decision:** Show one row per presented external display in the popover. Do not require a display selector before brightness adjustment.

- One display: no redundant heading.
- Two or more: show `Displays` heading.
- Many displays: scroll monitor rows while keeping the footer stationary.
- Mirrored sets: one logical row when one action controls the set.

**Rationale:** Display identity is essential to preventing wrong-monitor changes. Simultaneous rows expose state and remove an interaction before the primary action.

## D-007 — Use the native slider

**Status:** Accepted  
**Decision:** Brightness uses SwiftUI's native `Slider` or the underlying AppKit control only if a measured platform defect requires it.

**Rejected:** Custom track, thumb, drag gestures, gradients, or animated fill.

**Rationale:** The native slider already provides precision, pointer behavior, keyboard adjustment, focus ring, accessibility-adjustable semantics, accent adaptation, and platform styling.

## D-008 — Brightness has one user-facing invariant

**Status:** Accepted  
**Decision:** `0 = darkest`; `1 = brightest` in every presentation and control path.

**Rationale:** A slider must preserve direction regardless of hardware, gamma, or shade implementation. Backend-specific inversion occurs behind the frontend/backend boundary.

## D-009 — Fallback is quiet capability status

**Status:** Accepted  
**Decision:** When brightness still works through software or shade, the row remains a normal usable row with secondary text:

- `Software control`
- `Display shade`

Fallback is not presented as a red error. Technical detail is available through a small disclosure or diagnostics.

**Rationale:** The user's task is still possible. Treating a working fallback as failure creates unnecessary alarm and visual instability.

## D-010 — No slider when control is unavailable

**Status:** Accepted  
**Decision:** If no control path can adjust a display, remove the misleading slider and show `Brightness unavailable` with `Retry` and `Open Diagnostics` actions.

**Rationale:** A disabled slider with a stale percentage falsely communicates known state and capability.

## D-011 — No onboarding

**Status:** Accepted  
**Decision:** MyMonitor opens directly to its functional popover. Empty state and contextual explanations teach the interface in place.

**Rationale:** External-display brightness requires no account, project creation, permission setup, or complex mental model. A tutorial would delay the obvious task.

## D-012 — Settings navigation remains small and literal

**Status:** Accepted  
**Decision:** Maximum planned sections:

- General
- Displays
- Keyboard
- Advanced
- About

A section is hidden until it contains implemented behavior.

**Rejected:** License, Appearance, Help & Feedback, Developer, and feature-category sections without product need.

**Rationale:** Navigation should represent real user tasks, not make a small product appear larger.

## D-013 — Settings uses native sidebar and form anatomy

**Status:** Accepted  
**Decision:** Use standard Mac window chrome, a native sidebar/detail split, `Form`, `Section`, `LabeledContent`, `Toggle`, `Picker`, and native alerts/sheets.

**Rejected:** Repeated custom rounded cards, hidden traffic lights, custom titlebar backgrounds, fixed-height panels, and web-style settings tiles.

**Rationale:** Native settings anatomy provides known alignment, resizing, focus, active/inactive appearance, accessibility, and keyboard behavior.

## D-014 — Views consume presentation state, not display services

**Status:** Accepted  
**Decision:** Introduce an explicit presentation-state seam before the visual rewrite.

Views may render state and emit intent. Views may not enumerate displays, probe control methods, perform writes, choose tiers, own persistence, or observe workspace/display lifecycle notifications.

**Rationale:** Hardware-independent presentation state enables deterministic previews/tests and keeps asynchronous backend complexity from leaking into layout and interaction.

## D-015 — Popover rendering never waits for hardware

**Status:** Accepted  
**Decision:** Present the popover immediately from cached or explicit loading state. DDC reads/probes/writes never block the first visible frame.

**Target:** Under 100 ms click-to-visible on supported hardware, aspiring to one main-run-loop turn.

**Rationale:** Responsiveness is part of visual quality. A polished layout that stalls on I/O does not feel native.

## D-016 — Optimistic slider state is authoritative during interaction

**Status:** Accepted  
**Decision:** The thumb and percentage follow user input immediately. Backend throttling/acknowledgement may occur asynchronously, but stale snapshots cannot reverse the control. Failure becomes explicit recoverable state.

**Rationale:** Hardware timing must not destabilize the direct manipulation model.

## D-017 — No fixed brand accent in normal UI

**Status:** Accepted  
**Decision:** Respect the user's system accent color. Normal UI uses semantic system colors.

**Rejected:** Forced blue accent, custom gradient, per-monitor colors, or fixed dark/light foregrounds.

**Rationale:** System appearance is part of native identity and accessibility behavior.

## D-018 — Motion communicates state only

**Status:** Accepted  
**Decision:** Use native popover/control/window motion. Optional short transitions may communicate display insertion/removal or status changes and must respect Reduce Motion.

**Rejected:** Blur-scale popover entrance, springing cards, pulsing icon, animated gradients, and motion added only to showcase glass.

**Rationale:** The system already communicates spatial origin. Extra choreography slows a frequent utility and creates accessibility/maintenance cost.

## D-019 — Permissions are not introduced casually

**Status:** Accepted  
**Decision:** Brightness control and the core frontend request no Accessibility or Screen Recording permission. A future keyboard implementation must use the least-permission viable approach and document any new requirement before implementation.

**Rationale:** Permissions expand trust, onboarding, failure, testing, and support burden. They require a concrete product need and no lower-privilege alternative.

## D-020 — One implementation ticket per coherent change

**Status:** Accepted  
**Decision:** Follow `IMPLEMENTATION_PLAN.md` sequentially. Do not combine presentation architecture, popover rewrite, Settings, keyboard handling, diagnostics, accessibility hardening, and backend refactoring into one PR.

**Rationale:** Small changes are easier to verify on real hardware, review against the contract, revert, and debug.

## D-021 — OneMenu is inspiration, not a source asset

**Status:** Accepted  
**Decision:** Adopt OneMenu's calm density, immediacy, native composition, and separation of frequent controls from Preferences. Do not copy its branding, text, exact layout, icons, measurements, screenshots, feature set, or commercial identity.

**Rationale:** MyMonitor needs its own product expression and narrower information architecture while respecting the quality bar demonstrated by a strong native utility.

## D-022 — No nonfunctional settings

**Status:** Accepted  
**Decision:** A toggle, picker, navigation section, or button appears only when its backing behavior exists and its success/failure state is truthful.

Examples:

- No `Automatic updates` toggle before a real signed updater exists.
- No Keyboard section before keyboard behavior exists.
- No log-reveal action before a real log exists.

**Rationale:** Placeholder controls erode trust and make unfinished architecture look complete.

## D-023 — Accessibility and appearance are release requirements

**Status:** Accepted  
**Decision:** Keyboard navigation, VoiceOver, Light, Dark, Graphite, non-blue accent, Increased Contrast, Reduce Transparency, Reduce Motion, Differentiate Without Color, localization expansion, and long display names are part of completion—not later polish.

**Rationale:** System-native quality is defined by behavior across the user's Mac configuration, not by one default screenshot.

## D-024 — Frontend contract stabilizes before backend refinement

**Status:** Accepted  
**Decision:** Build the presentation seam and complete the frontend tickets before a broad backend redesign. Backend work then makes the established UI truthful, responsive, and reliable without reopening product anatomy.

**Rationale:** UI/UX is currently the highest-risk product area. Separating the contract from backend optimization prevents architecture work from continuously reshaping the interface.
