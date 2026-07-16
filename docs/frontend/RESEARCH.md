# Frontend Research

This document records the evidence behind the frontend contract. It distinguishes platform guidance from product inspiration and prevents future work from turning subjective screenshots into undocumented implementation rules.

## Research questions

1. Where should Liquid Glass appear in a focused macOS utility?
2. Which system components should MyMonitor inherit instead of rebuilding?
3. What makes a menu-bar utility feel immediate and native?
4. How should a monitor app expose multiple control paths without leaking implementation complexity?
5. Which competitor patterns are useful, and which would expand MyMonitor beyond its product boundary?

## Primary platform sources

### Apple: Meet Liquid Glass

Source: [Meet Liquid Glass — WWDC25](https://developer.apple.com/videos/play/wwdc2025/219/)

Relevant platform guidance:

- Liquid Glass creates a distinct functional layer for controls and navigation above content.
- Menus and transient surfaces should preserve a direct spatial relationship with the control that invoked them.
- The material adapts to context, appearance, focus, and accessibility settings.
- Apple explicitly says Liquid Glass is best reserved for the navigation layer.
- Apple explicitly warns against applying glass to ordinary content and against stacking glass on glass.
- Regular glass is the versatile adaptive variant. Clear glass is only appropriate over media-rich content with deliberate dimming and bold foreground content.
- Tint should be selective and should identify a primary action or distinct functional purpose.
- Reduce Transparency, Increased Contrast, and Reduce Motion are automatically reflected by system Liquid Glass behavior.

MyMonitor conclusions:

- The native popover is the floating material surface. Monitor rows inside it remain ordinary content.
- Settings uses the system window/sidebar/form hierarchy rather than custom translucent cards.
- The app uses Regular system material behavior. There is no valid use case for Clear glass in v1.
- Accent tint is used sparingly: slider fill, selection, and a genuinely primary action only.
- Custom glass rendering is prohibited unless a native component cannot express a required interaction.

### Apple: Get to know the new design system

Source: [Get to know the new design system — WWDC25](https://developer.apple.com/videos/play/wwdc2025/356/)

Relevant platform guidance:

- Structure and grouping should replace unnecessary decorative backgrounds and borders.
- Items should be grouped by function and frequency; crowded bars are a signal to remove or move secondary actions.
- The system's new geometry uses concentric relationships between parent and child shapes.
- Mini, Small, and Medium macOS controls remain rounded rectangles; capsules are better reserved for standout actions in desktop layouts.
- Sidebars on macOS are inset, system-managed navigation surfaces.
- Text labels are preferred when a symbol is ambiguous.
- Components should retain the same anatomy and core interactions across contexts.

MyMonitor conclusions:

- Do not create a card for every section merely to show a corner radius.
- The Settings sidebar is short and literal: General, Displays, Keyboard, Advanced, About.
- Ordinary compact controls use standard macOS control sizes.
- A capsule is not the default button shape. It is allowed only when the native large/prominent style produces it or a standout action clearly requires it.
- Preferences and Quit use text because their meanings are clearer than isolated symbols.

### Apple documentation and HIG references

- [Liquid Glass overview](https://developer.apple.com/documentation/technologyoverviews/liquid-glass)
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines)
- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Menus and actions](https://developer.apple.com/design/human-interface-guidelines/menus-and-actions)
- [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)
- [Settings](https://developer.apple.com/design/human-interface-guidelines/settings)
- [`MenuBarExtra`](https://developer.apple.com/documentation/swiftui/menubarextra)
- [`Settings` scene](https://developer.apple.com/documentation/swiftui/settings)
- [`NavigationSplitView`](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [`Form`](https://developer.apple.com/documentation/swiftui/form)
- [`GlassEffectContainer`](https://developer.apple.com/documentation/swiftui/glasseffectcontainer)
- [`SMAppService`](https://developer.apple.com/documentation/servicemanagement/smappservice)

These pages define the available native vocabulary. Their presence does not mean every API belongs in MyMonitor. The smallest correct platform component wins.

## Product inspiration

### OneMenu

Source: [OneMenu](https://coffeebreak.software/one-menu/)

Observed strengths from the public product page and product-owner screenshots:

- A compact menu-bar surface with high information density and very little ceremony.
- Familiar native controls and labels.
- Clear separation between frequent controls and Preferences.
- Preferences use standard Mac window chrome and a sidebar/content layout.
- The monitor feature is described simply as a brightness slider that "just works."
- Testimonials repeatedly praise minimal, native-feeling, responsive behavior rather than visual novelty.

What MyMonitor adopts:

- Calm density.
- Immediate access from the menu bar.
- A stationary Preferences/Quit footer.
- A real Settings window for infrequent configuration.
- The principle that backend complexity should disappear behind a direct control.

What MyMonitor rejects:

- OneMenu's broad utility-hub scope.
- CPU/memory/disk rings.
- Window manager, clipboard, keyboard cleaning, and upgrade surfaces.
- OneMenu's exact layout, copy, icons, dimensions, branding, or commercial identity.

The goal is not "OneMenu but fewer features." The goal is the monitor utility Apple might have shipped, informed by OneMenu's discipline.

## Monitor-app market scan

### MonitorControl

Source: [MonitorControl](https://monitorcontrol.app/) and its linked open-source repository.

Useful lesson:

- A menu-bar monitor controller can remain focused and dependency-light while providing hardware and software control paths.

Caution:

- MyMonitor must not inherit legacy UI patterns simply because backend code is adapted from the project. Backend provenance does not dictate frontend design.

### Lunar

Source: [Lunar](https://lunar.fyi/)

Useful lessons:

- Users benefit from consistent brightness-key behavior.
- Multiple displays need explicit per-display identity.
- DDC, Apple-native control, and software fallback have materially different capabilities.
- Fallback should be understandable when hardware control fails.

Caution:

- Lunar intentionally supports a very broad feature set: sync, sensors, schedules, blackout, input switching, XDR, CLI, presets, and more. MyMonitor must not surface that complexity in its core navigation.
- Control-method detail belongs in quiet status text or Advanced settings, not the primary task hierarchy.

### BetterDisplay

Source: [BetterDisplay](https://github.com/waydabber/BetterDisplay)

Useful lessons:

- Automatic DDC capability detection is valuable.
- Display identity and per-display configuration matter.
- A mature monitor utility needs explicit states for unsupported capabilities and fallback control.

Caution:

- BetterDisplay is a comprehensive display-management suite. Its dense feature inventory is the opposite of MyMonitor's product boundary.
- MyMonitor should not create preference categories for hypothetical future features.

### DisplayBuddy

Source: [DisplayBuddy](https://displaybuddy.app/)

Useful lesson:

- External display control is a frequent action that belongs in the menu bar, with deeper configuration kept elsewhere.

Caution:

- Marketing screenshots are not a substitute for platform behavior. MyMonitor uses system components rather than reproducing another app's presentation.

## First-principles findings

### The primary user intent is adjustment, not inspection

A user opens the popover to change a monitor now. Therefore:

- Brightness controls are visible without navigation.
- The display name and value are readable at a glance.
- Diagnostics and control-tier selection do not compete with the slider.
- The popover never opens onto a dashboard, welcome state, or settings list.

### Speed is part of visual quality

A visually perfect popover that waits for DDC is not polished. The interface must render from cached/presentation state immediately and refine status asynchronously.

Target perception:

- Status-item click produces a visible popover within one frame of the main run loop when possible.
- Monitor rows do not reflow after opening unless displays actually changed.
- Slider movement is local and continuous; hardware acknowledgement cannot make the thumb snap backward.

### A fallback is a capability state, not an error page

If DDC fails but gamma or shade works, the core user task is still available.

Therefore:

- The row remains normal.
- A quiet secondary label says `Software control` or `Display shade`.
- An optional info disclosure explains limitations.
- Red is reserved for a state where no control path can perform the task.

### The Settings window is not a second product

Settings exists to configure behavior that would clutter the frequent path.

A preference earns a visible control only when:

1. The behavior exists.
2. The user can understand its effect.
3. The default cannot satisfy every user.
4. The control can be tested.

Otherwise it remains absent.

## Pattern decisions

| Pattern | Decision | Reason |
|---|---|---|
| Native `NSPopover` | Adopt | Correct spatial relationship, dismissal, focus, shadow, and material behavior. |
| Custom floating `NSPanel` | Reject for main popover | Recreates system lifecycle and creates more failure modes. |
| Glass cards inside popover | Reject | Glass-on-glass muddies hierarchy. |
| Native `Slider` | Adopt | Correct pointer, keyboard, focus, accessibility, and macOS 26 styling. |
| Custom slider | Reject for v1 | High interaction and accessibility risk with no product advantage. |
| Per-display rows | Adopt | Immediate identity and control for multiple monitors. |
| Display selector dropdown | Reject initially | Adds an interaction before the primary action and hides state. |
| Native Settings sidebar | Adopt | Familiar Mac information architecture and scalable window behavior. |
| Large branded header | Reject | Consumes space without aiding the task. |
| Onboarding carousel | Reject | Brightness needs no tutorial or permission. |
| Persistent error banner | Reject | Overstates fallback conditions and destabilizes layout. |
| Contextual status text | Adopt | Communicates capability without stealing focus. |
| Fixed dark theme | Reject | Violates system appearance and accessibility expectations. |
| System accent color | Adopt | Respects user configuration and native control behavior. |
| Custom entrance spring | Reject | The system popover already communicates origin and state. |
| Native insertion/removal transitions | Allow sparingly | Useful only when connected-display state actually changes. |

## Open research questions

These questions must be resolved during implementation tickets through prototype evidence, not speculation:

1. Whether `NSPopover` or a SwiftUI `MenuBarExtra` window style produces the best keyboard focus and exact anchoring for the required row layout on macOS 26. The current rescue uses `NSPopover`; replacement requires measured benefit.
2. Whether the Settings window is best hosted through a SwiftUI `Settings` scene or an AppKit `NSWindowController` around SwiftUI content given the current custom app lifecycle.
3. The exact native control size that provides the best slider precision in a 300–320 point popover.
4. Whether the control-method label should always be visible or only appear for fallback states after user testing.
5. The maximum monitor count before the popover requires a scrolling region.

Each question has a dedicated spike or ticket in `IMPLEMENTATION_PLAN.md`.

## Research standard for future changes

A future frontend proposal must identify:

- The user problem.
- The platform component considered first.
- Why the current specification cannot solve it.
- Evidence from Apple guidance or a reproducible usability issue.
- Accessibility and keyboard implications.
- The smallest change that resolves the problem.

"Looks cooler" and "more glass" are not sufficient reasons.
