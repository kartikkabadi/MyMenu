# F14 Visual and Performance Validation

F14 turns frontend quality into repeatable evidence. It does not replace real-hardware sign-off; it makes presentation states, architectural constraints, and click-to-visible measurement reproducible before hardware testing.

## Deterministic preview gallery

Open `MyMonitor/Debug/FrontendPreviewGallery.swift` in Xcode and use the canvas.

Required popover previews:

- Detecting without cached displays
- Empty
- One hardware-controlled display
- Two mixed-control displays
- Checking control method
- Unavailable control
- Top-level failure
- Long monitor name
- Four displays
- Eight-display overflow stress
- Dark appearance

Required Settings previews:

- General
- Displays
- Keyboard
- Advanced
- About
- Dark appearance

The previews use the real production views and presentation stores with deterministic hardware-free controllers. They do not call Core Graphics, DDC, gamma, overlay, Service Management, Carbon hot-key registration, or `UserDefaults`.

## Screenshot review set

Capture the applicable preview or running-app state at 1× or 2× without cropping system chrome:

1. Empty popover — Light
2. One hardware display — Light and Dark
3. Two mixed displays — Light and Dark
4. Eight-display scrolling popover
5. Fallback disclosure
6. Unavailable control and recovery actions
7. General Settings
8. Displays Settings detail
9. Keyboard Settings
10. Advanced diagnostics
11. About and attribution
12. Increased Contrast
13. Reduce Transparency
14. Long monitor name / text-expansion state

Screenshots are review evidence, not pixel-locked golden files. Native macOS rendering may legitimately change between OS builds.

## Popover presentation measurement

`PopoverWindowController` emits an `os_signpost` interval named:

```text
Popover Presentation
```

Subsystem:

```text
com.mymonitor.MyMonitor
```

Category:

```text
Frontend
```

The interval begins when the status-item action starts opening the popover and ends when the hosted SwiftUI view receives `viewDidAppear`.

Measure with Instruments:

1. Build and run a normally installed Debug or Release app.
2. Open Instruments and choose Points of Interest.
3. Filter for `Popover Presentation`.
4. Open and close the popover at least 20 times.
5. Repeat with one display, multiple displays, after wake, and on a secondary menu bar.
6. Record median, p95, and worst observed duration.

Target:

- Median under 100 ms on supported Apple silicon hardware.
- No DDC probe, display enumeration, or hardware write on the click-to-visible path.
- No visible row reorder or height jump after presentation.

The signpost measures app-side click-to-visible work. It does not establish end-to-end input latency by itself.

## CI contract

`scripts/validate_frontend_contract.sh` fails when production frontend code introduces:

- `NSPanel`
- custom `.glassEffect()`
- nested material backgrounds inside Views
- fixed SwiftUI/AppKit RGB colors
- decorative gradients
- display router/backend/Core Graphics types in Views
- `UserDefaults` in Views
- the deleted `GlassBrightnessControl`
- a SwiftUI view source file over 450 lines
- deletion of required preview states
- deletion of the localization catalog
- replacement of the native `NSPopover` host

CI also runs:

- presentation tests
- frontend contract validation
- project regeneration
- Xcode 26 Debug build
- Xcode 26 Release build
- whitespace validation

## Manual release gate

F14 is complete only after the exact release candidate is manually checked for:

- Light, Dark, Graphite, and a non-blue accent
- Increased Contrast
- Reduce Transparency
- Reduce Motion
- Differentiate Without Color
- keyboard-only traversal
- full VoiceOver task flow
- one, two, four, and eight display layouts
- long monitor names and expanded strings
- rapid popover toggling
- minimum/default/wide Settings sizes
- active/inactive Settings appearance
- secondary menu bar and fullscreen Space behavior

Real DDC, gamma, shade, hot-plug, wake, and persistence behavior remain part of the real-hardware sign-off in `QA_MATRIX.md`.
