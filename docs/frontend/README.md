# MyMonitor Frontend Contract

Status: **Canonical specification**  
Target: **macOS 26+, Apple silicon, SwiftUI + AppKit**  
Product: **External-monitor control only**  
Reference date: **2026-07-16**

This directory defines the frontend MyMonitor is allowed to become. It is deliberately more specific than a mood board. Implementations must satisfy the anatomy, behavior, accessibility, performance, and validation requirements here before visual polish is considered complete.

## North star

> MyMonitor should feel like Apple quietly shipped an external-monitor control for the Mac menu bar.

The app should be instantly understandable, fast enough to feel synchronous, and visually native enough that users do not notice a separate design system.

## Product promise

MyMonitor has one job:

1. Detect external displays.
2. Show their current brightness state immediately.
3. Let the user change brightness predictably.
4. Select the best available control path without exposing backend complexity.
5. Stay reliable across hot-plug, wake, Spaces, fullscreen, appearance, and accessibility changes.

The frontend must not grow into a generic utility hub. Window management, clipboard history, system monitoring, disk cleaning, app launching, AI, accounts, analytics, and marketing surfaces are outside the product.

## Canonical documents

Read these in order before changing UI code:

1. [`RESEARCH.md`](RESEARCH.md) — source-backed findings and what MyMonitor adopts or rejects.
2. [`PRODUCT_SPEC.md`](PRODUCT_SPEC.md) — complete surface anatomy, states, flows, copy, and interaction rules.
3. [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) — native components, materials, typography, color, geometry, motion, and symbols.
4. [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) — one-ticket-at-a-time execution sequence and architecture boundaries.
5. [`QA_MATRIX.md`](QA_MATRIX.md) — objective visual, interaction, accessibility, and performance acceptance tests.
6. [`DECISIONS.md`](DECISIONS.md) — binding product and design decisions with rationale.

When documents disagree, the more specific requirement wins. A deliberate product decision must update all affected documents in the same pull request.

## Non-negotiable rules

### Native means native

Use the actual macOS component or behavior whenever one exists:

- `NSStatusItem` for the menu-bar presence.
- `NSPopover` for the transient control surface.
- Native SwiftUI `Slider`, `Toggle`, `Button`, `Menu`, `Picker`, `Form`, `Section`, `LabeledContent`, `List`, and `NavigationSplitView` where appropriate.
- Standard macOS window chrome, traffic lights, focus rings, keyboard navigation, menus, and accessibility semantics.
- SF Symbols and system typography.
- Semantic system colors and the user's accent color.

Do not rebuild system controls to make them look more "premium." The system behavior is the premium behavior.

### Liquid Glass is structural, not decorative

Liquid Glass belongs to the floating control and navigation layer. It is not a background treatment for every row.

- Do not place a glass card inside the glass popover.
- Do not stack materials.
- Do not draw translucent borders around every group.
- Do not add arbitrary blur, glow, gradient, noise texture, or chromatic edge effects.
- Do not use `.glassEffect()` merely because the API exists.
- Do not hard-code a dark appearance.

The resting interface should be quiet. Native controls provide their own interaction and material response.

### No design-token theatre

A small Mac utility does not need a web-scale token system. Keep only values that express a real product invariant, such as popover width or spacing between monitor rows.

Forbidden patterns:

- Many near-identical corner-radius constants.
- Fixed RGB colors for normal UI.
- Custom shadows intended to imitate system elevation.
- Multiple bespoke button styles.
- Component wrappers that only add a rounded rectangle.
- A "glass surface" component used around ordinary content.

### One job per surface

MyMonitor has two primary surfaces:

1. **Menu-bar popover** — frequent brightness control.
2. **Settings window** — infrequent configuration and diagnostics.

No onboarding carousel, dashboard, home screen, upgrade banner, or marketing call-to-action belongs in the native app core.

### One ticket at a time

The implementation plan is intentionally sequential. Each ticket must:

1. Preserve a passing build.
2. Implement one coherent behavior or surface slice.
3. Include objective tests or a manual QA checklist.
4. Avoid speculative infrastructure for later tickets.
5. Stop when its acceptance criteria are satisfied.

Do not combine the popover rewrite, Settings window, keyboard shortcuts, launch at login, diagnostics, and backend work into one pull request.

## Target surface map

```text
Menu bar
└── MyMonitor status item
    └── Native transient popover
        ├── zero-display state
        ├── one or more monitor rows
        ├── contextual status/error disclosure
        └── Preferences… / Quit footer

Settings window
├── General
├── Displays
├── Keyboard
├── Advanced
└── About
```

Only sections backed by real behavior may be visible. A section must not ship with placeholder controls.

## Visual quality definition

"Polished" means:

- The app follows macOS spacing, sizing, focus, window, and menu conventions.
- The hierarchy is clear without decorative boxes.
- Every state has intentional copy and layout.
- Light, Dark, Graphite, Increased Contrast, Reduce Transparency, and Reduce Motion all remain legible.
- Keyboard and VoiceOver users can complete every core action.
- The popover opens instantly and never visibly waits for monitor probing.
- Slider movement is continuous and does not jump, reverse, or revert after release.
- Settings resize naturally without stretched cards or clipped labels.
- The app does not look copied from OneMenu; it applies the same discipline to a narrower product.

## Inspiration boundary

OneMenu is a product-quality reference for calm density, native composition, responsive interaction, and the placement of Preferences/Quit in a menu-bar utility. It is not a template to clone.

Do not copy:

- OneMenu branding, marks, text, commercial identity, assets, or exact composition.
- Its CPU, memory, disk rings.
- Its feature list or preference categories.
- Its upgrade button.
- Pixel-specific measurements inferred from screenshots.

MyMonitor should be recognizably its own focused monitor app.

## Frontend/backend boundary

Views render presentation state and emit user intent. Views must not:

- Probe DDC.
- Enumerate displays directly.
- Decide fallback tiers.
- Read or write private display APIs.
- Debounce hardware writes.
- Own persistence keys.
- Perform lifecycle teardown.

The frontend consumes a small observable presentation model with explicit states. See `IMPLEMENTATION_PLAN.md`.

## Merge gates

A frontend pull request is not complete unless all applicable gates pass:

- Xcode 26 Debug build.
- `git diff --check`.
- No new non-Apple UI dependency.
- No new fixed UI RGB value without an approved semantic need.
- No new custom blur, glass card, border, or shadow abstraction without a documented native-component gap.
- Keyboard navigation manually verified.
- VoiceOver labels and values specified.
- Light and Dark appearance manually verified.
- Reduce Transparency, Increased Contrast, and Reduce Motion manually verified when materials or motion changed.
- Screenshots captured for the states listed in `QA_MATRIX.md`.
- Real-hardware validation when a change affects displayed brightness or connected-display state.

## Definition of done for the frontend programme

The frontend programme is complete only when:

1. The production popover matches the anatomy and states in `PRODUCT_SPEC.md`.
2. Settings contains only implemented controls and follows the specified navigation structure.
3. Every component uses the native mapping in `DESIGN_SYSTEM.md` unless an exception is recorded.
4. All required QA matrix rows pass.
5. No dead experimental UI remains in the source tree.
6. A new contributor can implement or review a ticket without guessing the intended behavior.
