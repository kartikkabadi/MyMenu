# F2 Native Surface Spike

Status: **Complete**  
Decision: **Keep `NSStatusItem` + transient `NSPopover`**  
Settings host: **Defer exact window host to F7; keep one AppKit-owned window instance**

## Question

Should MyMonitor continue using its current AppKit status item and native transient popover, or rewrite the application lifecycle around SwiftUI `MenuBarExtra` before implementing the visual frontend?

## Current production path

The current app already has the platform primitives required by the frontend contract:

- An accessory `NSApplication` lifecycle.
- One `NSStatusItem` with a template `display` symbol.
- One retained `NSPopover` instance.
- `.transient` dismissal behavior.
- A SwiftUI root view hosted by `NSHostingController`.
- Explicit teardown through the existing app delegate and display controller.

The current visible problems are not caused by choosing `NSPopover`:

- The popover is forced to a fixed width and height.
- The SwiftUI root paints another material background inside the popover.
- The view contains a redundant branded header.
- The controller refreshes/re-probes immediately before showing the popover.
- The footer does not yet follow the final product anatomy.
- The monitor rows use temporary typography and spacing.

All of these can be corrected while preserving the native surface host.

## Options considered

### Option A — `NSStatusItem` + transient `NSPopover`

#### Strengths

- The popover is explicitly anchored to the clicked status-bar button.
- `.transient` supplies outside-click and Escape dismissal behavior.
- AppKit owns the popover material, shadow, corner treatment, placement, and screen-edge behavior.
- The retained controller makes duplicate-surface prevention straightforward.
- It fits the existing accessory-app lifecycle and explicit display-controller teardown.
- SwiftUI remains available for all content through `NSHostingController`.
- The app can control when content is refreshed without delaying presentation.
- The current production path already builds and has survived the monitor-only rescue.

#### Weaknesses to address

- Content-driven sizing requires deliberate fitting-size synchronization.
- Initial keyboard focus may require an explicit focus handoff after presentation.
- Settings-window coordination remains an AppKit/SwiftUI boundary rather than a pure SwiftUI scene.

These are bounded implementation tasks, not reasons to replace the host.

### Option B — SwiftUI `MenuBarExtra`

#### Potential strengths

- A more declarative SwiftUI application/scene model.
- Direct composition with a SwiftUI `Settings` scene in a future lifecycle rewrite.
- Less explicit AppKit code for a simple menu-style extra.

#### Costs and risks for MyMonitor now

- The current executable is manually launched as an accessory `NSApplication`, not a SwiftUI `App` scene hierarchy.
- Adopting `MenuBarExtra` would require changing the application lifecycle before delivering any user-visible design improvement.
- Window-style behavior, focus, exact presentation, and multi-display anchoring would still require real-hardware/manual validation.
- The rewrite would mix lifecycle architecture with the popover design programme, violating the one-ticket rule.
- The existing explicit teardown path for display backends would need to be redesigned and revalidated.
- There is no demonstrated defect in `NSPopover` that `MenuBarExtra` is known to solve for this product.

## Evidence-based decision

Keep Option A.

The native host already satisfies the important structural requirements:

| Requirement | Current host capability | F3/F4 action |
|---|---|---|
| Source relationship | Anchored to `NSStatusBarButton` | Preserve. |
| Native material | Supplied by `NSPopover` | Remove inner material background. |
| Transient dismissal | `.transient` | Preserve and manually verify. |
| One surface instance | Retained controller/popover | Preserve and stress-test rapid toggles. |
| SwiftUI content | `NSHostingController` | Preserve. |
| Content-driven size | Not currently implemented | Add fitting-size synchronization. |
| Immediate first frame | Currently refreshes before show | Show first; refresh asynchronously only when needed. |
| Keyboard focus | Not fully specified in current code | Validate in F3/F4. |
| Settings coordination | Not implemented | Add only when real Settings content exists in F7. |

No prototype of `MenuBarExtra` is justified until a reproducible production problem remains after the `NSPopover` shell is corrected.

## Settings-window decision

F2 does not create a Settings window.

The original F3 text required a working `Preferences…` action before F7 defines and implements the real Settings anatomy. That conflicts with the binding rule that no nonfunctional or placeholder setting may ship.

Resolution:

- F3 implements the native popover shell and a stationary footer containing only actions that work at that point.
- `Quit` is present in F3.
- `Preferences…` is added in F7 at the same time as the real, single-instance Settings window shell.
- The final product anatomy remains `Preferences…` leading and `Quit` trailing.

This is a sequencing correction, not a product-design change.

## F3 implementation constraints derived from the spike

1. Do not create a second material/background inside the popover.
2. Do not set a fixed popover height.
3. Keep a narrow, validated fixed width while height follows content.
4. Do not refresh/re-probe synchronously before `show`.
5. Keep one retained popover and hosting controller.
6. Preserve `.transient` behavior and status-item anchoring.
7. Remove custom entrance animation; rely on the native popover.
8. Keep current row controls temporarily; F4 owns the final native row.
9. Add only working footer actions.
10. Do not introduce `NSPanel` or a SwiftUI lifecycle rewrite.

## Revisit trigger

Reconsider `MenuBarExtra` only if the corrected `NSPopover` path has a reproducible defect that cannot be solved without violating platform behavior, such as:

- Incorrect anchoring across supported multi-menu-bar configurations.
- Unfixable keyboard-focus behavior.
- Duplicate/stale surface behavior caused by AppKit rather than application code.
- A future macOS API deprecation.
- A broader application-lifecycle migration with independent product value.

A revisit requires a measured prototype and a separate architecture PR.
