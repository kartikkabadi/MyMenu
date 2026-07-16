# Product and Interaction Specification

## 1. Product definition

MyMonitor is a menu-bar utility for controlling external-monitor brightness. It should feel like a small missing piece of macOS, not a third-party dashboard.

### Core job

> Open, identify the monitor, adjust brightness, close.

### Secondary jobs

- Understand why a monitor is using a fallback method.
- Configure per-display limits and keyboard behavior.
- Re-detect displays or export diagnostics when something is wrong.
- Launch automatically at login.

### Non-goals

- Window management.
- Clipboard history.
- System monitoring.
- Disk cleaning.
- Monitor arrangement, resolution, refresh rate, HDR, input switching, volume, color calibration, or virtual displays in v1.
- Accounts, licensing, subscriptions, upgrade prompts, analytics, or cloud sync.
- A persistent main window.

## 2. Information architecture

MyMonitor has exactly two primary UI surfaces.

### 2.1 Menu-bar popover

Purpose: frequent control.

Contains:

1. Connected-display state.
2. One brightness row per presented external display.
3. Contextual fallback/error state when needed.
4. Footer with `Preferences…` and `Quit`.

### 2.2 Settings window

Purpose: infrequent configuration.

Sidebar sections:

1. General
2. Displays
3. Keyboard
4. Advanced
5. About

A section is hidden until at least one real, working control belongs to it. Empty shells do not ship.

## 3. Menu-bar status item

### 3.1 Symbol

Default symbol: `display`.

Requirements:

- Template rendering.
- No color in the resting state.
- Accessibility label: `MyMonitor`.
- Tooltip: `MyMonitor`.
- Standard square status-item hit target.

Do not show a sun symbol as the app identity; a display symbol more clearly distinguishes the app from built-in brightness controls and communicates external-monitor scope.

### 3.2 Interaction

- Primary click toggles the popover.
- Clicking outside dismisses it.
- Escape dismisses it.
- Clicking the status item while open closes it.
- Reopening restores the most recent keyboard focus only when the focused display still exists; otherwise focus enters the first interactive control.
- The status item never opens onboarding or Settings automatically.

### 3.3 Status indication

The menu-bar icon remains monochrome in normal and fallback operation.

Allowed exceptional indication:

- A small system badge or alternate symbol may indicate that external displays exist but none is controllable.

Do not use animation, pulsing, permanent warning color, or numeric badges.

## 4. Popover shell

### 4.1 Platform behavior

- Native transient `NSPopover` anchored to the status item.
- System material, shadow, corner treatment, focus, dismissal, and appearance.
- No inner full-surface background.
- No custom floating panel unless a prototype proves a native popover cannot meet a documented requirement.

### 4.2 Sizing

- Preferred width: **312 points**.
- Allowed tuning range: **300–320 points** after testing native slider precision and label wrapping.
- Content-driven height.
- Minimum practical height: empty state plus footer.
- Maximum content height before scrolling: **440 points**.
- Footer remains stationary when monitor rows scroll.
- No blank spacer used to force a fixed height.

### 4.3 Outer layout

- Horizontal content inset: 14 points.
- Top content inset: 12 points.
- Bottom content inset above footer: 10 points.
- Inter-row spacing: 12 points.
- Separator uses the native `Divider` appearance only where it clarifies the footer boundary or separate monitor rows.

Values are starting constraints, not permission to implement a custom geometry system. Native control metrics take precedence when they conflict.

## 5. Popover states

The popover must render immediately from presentation state. Detection/probing may update quiet status content later without replacing the whole surface.

### 5.1 Loading state

A loading state is allowed only when the app has no cached display snapshot and discovery has not completed.

```text
┌──────────────────────────────┐
│ Detecting displays…          │
│                              │
│ Preferences…            Quit │
└──────────────────────────────┘
```

Rules:

- Use a small native progress indicator only when discovery genuinely lasts long enough to be perceived.
- Do not show skeleton cards.
- Do not delay popover presentation to avoid this state.
- If no result arrives within the frontend timeout, transition to the error/empty recovery state rather than spinning indefinitely.

### 5.2 No external displays

```text
┌──────────────────────────────┐
│          [display]           │
│                              │
│    No external displays      │
│                              │
│ Connect a display and        │
│ MyMonitor will detect it.    │
│                              │
│          Refresh             │
├──────────────────────────────┤
│ Preferences…            Quit │
└──────────────────────────────┘
```

Copy:

- Title: `No external displays`
- Body: `Connect a display and MyMonitor will detect it.`
- Action: `Refresh`

Rules:

- `Refresh` is a native button and does not repeatedly animate the whole surface.
- No setup instructions, permissions, product illustration, or onboarding.
- The built-in display is not shown.

### 5.3 One controllable display

```text
┌──────────────────────────────┐
│ Dell U2723QE            72%  │
│  ☾  ━━━━━━━━━●━━━━━━  ☀︎     │
│ Hardware control             │
├──────────────────────────────┤
│ Preferences…            Quit │
└──────────────────────────────┘
```

Rules:

- Do not show a redundant `Displays` heading.
- Display name uses one line and truncates in the middle or tail only when necessary; percentage remains visible.
- Percentage uses monospaced digits.
- The slider occupies the majority of the row width.
- Control-method status is tertiary and may be omitted for hardware control after usability testing; fallback states must remain explicit.

### 5.4 Multiple displays

```text
┌──────────────────────────────┐
│ Displays                     │
│                              │
│ Studio Display          80%  │
│  ☾  ━━━━━━━━━━━●━━━━  ☀︎     │
│ Hardware control             │
│                              │
│ Dell U2723QE            55%  │
│  ☾  ━━━━━━━●━━━━━━━━  ☀︎     │
│ Display shade                │
├──────────────────────────────┤
│ Preferences…            Quit │
└──────────────────────────────┘
```

Rules:

- Heading `Displays` appears only with two or more presented rows.
- Each monitor remains simultaneously visible until content exceeds maximum height.
- Order is stable between opens. Preferred order: macOS display arrangement or a persisted explicit order; alphabetical order is a temporary fallback only.
- Mirrored displays appear as one logical row when one brightness action controls the mirrored set.
- Four or more rows may scroll; footer does not scroll.

### 5.5 Detecting control method

The row is usable from cached state when possible.

Quiet temporary copy:

- `Checking hardware control…`

Rules:

- Do not disable the entire popover.
- Do not show raw tier names, DDC commands, spinner overlays, or modal alerts.
- The final method crossfades or updates without moving the slider.

### 5.6 Fallback active

Supported fallback labels:

- `Software control`
- `Display shade`

Optional disclosure button:

- Symbol: `info.circle`
- Accessibility label: `About control method for <display name>`

Disclosure content example:

```text
MyMonitor could not use hardware brightness through this connection, so it is using a display shade. The monitor's physical backlight is unchanged.
```

Rules:

- Fallback is not red when brightness adjustment still works.
- The status label is visible in the normal row.
- Details use a native popover, help tag, or compact disclosure—not a permanent card.

### 5.7 No usable control path

```text
┌──────────────────────────────┐
│ Dell U2723QE                 │
│ Brightness unavailable       │
│                              │
│ Retry       Open Diagnostics │
├──────────────────────────────┤
│ Preferences…            Quit │
└──────────────────────────────┘
```

Rules:

- Slider is absent, not disabled with a misleading value.
- Use semantic error styling sparingly on the status text or symbol.
- `Retry` retries only this display.
- `Open Diagnostics` opens Advanced settings focused on this display's diagnostic record.
- Error copy must be actionable and must not expose private API jargon by default.

### 5.8 Display disconnected while open

- Remove the row using a short native insertion/removal transition when Reduce Motion is off.
- With Reduce Motion, update without movement.
- If the last row disappears, transition to the no-display state.
- Never leave a stale slider that continues accepting input.

## 6. Monitor row anatomy

### 6.1 Header line

Left:

- Display name.
- Font: system body/callout, medium emphasis.
- One line.

Right:

- Rounded integer percentage, `0%` through `100%`.
- Monospaced digits.
- Accessibility-hidden when the slider's accessibility value already communicates it, to avoid duplicate VoiceOver output.

### 6.2 Slider line

- Leading symbol: `moon` or `sun.min`.
- Native `Slider` in `0...1`.
- Trailing symbol: `sun.max`.
- Symbols are secondary and not independently interactive.
- Slider label: `Brightness for <display name>`.
- Accessibility value: `<integer> percent`.
- Accessibility hint: `Adjusts external-display brightness.`

### 6.3 Interaction semantics

- Left is darker; right is brighter.
- Dragging updates the visual value immediately.
- Hardware writes may be throttled, but the presentation state follows the pointer.
- Releasing commits/persists the final value.
- A failed write does not silently snap the UI back. It transitions to an explicit recoverable state.
- Arrow keys adjust by 1 percentage point or the closest practical native increment.
- Shift + arrow adjusts by 5 percentage points when implementable without replacing native slider behavior.
- Home sets the configured minimum; End sets the configured maximum only if the platform behavior can be added accessibly and predictably.
- Scroll-wheel adjustment is not added in v1 unless native slider behavior provides it safely.

### 6.4 Click targets

- The native slider track/thumb owns slider input.
- Display name and percentage are not hidden drag targets.
- Info disclosure has at least the native minimum target size for its control size.

## 7. Popover footer

```text
Preferences…                               Quit
```

Requirements:

- Native plain/text buttons.
- `Preferences…` on the leading edge.
- `Quit` on the trailing edge.
- One native separator above.
- `Preferences…` opens or focuses the Settings window and dismisses the popover.
- `Quit` performs orderly backend teardown and terminates.
- Command-Q remains available when the app is active.
- No version text, branding, social links, donation, upgrade, or update control in the footer.

## 8. Settings window

### 8.1 Window behavior

- Standard macOS window chrome and traffic lights.
- Default size: **720 × 500 points**.
- Minimum size: **620 × 420 points**.
- Resizable.
- Restores previous size and position using system window restoration where practical.
- Opening Settings focuses an existing window instead of creating duplicates.
- Closing Settings does not quit the menu-bar app.
- No custom titlebar background or hidden traffic lights.

### 8.2 Navigation

Preferred structure: native sidebar/detail split view.

Sidebar width:

- System-managed with a practical preferred width around 180–210 points.
- User-resizable only if native behavior provides it without harming the compact window.

Sections and symbols:

| Section | Symbol | Purpose |
|---|---|---|
| General | `gearshape` | Startup and global behavior. |
| Displays | `display.2` | Per-display configuration and status. |
| Keyboard | `keyboard` | Brightness-key and shortcut behavior. |
| Advanced | `wrench.and.screwdriver` | Recovery and diagnostics. |
| About | `info.circle` | Version, source, attribution. |

Do not include a License section, Help & Feedback section, Appearance theme section, Developer section, or feature categories that MyMonitor does not have.

### 8.3 Sidebar selection

- The first launch opens General.
- The most recent valid selection may be restored.
- Deep links from an error may open Advanced or Displays with the relevant display selected.
- Selection uses the system accent color and native sidebar row behavior.

## 9. General settings

### 9.1 Startup section

Control:

- Toggle: `Launch MyMonitor at login`

Behavior:

- Backed by `SMAppService` or the current supported system API.
- State reflects actual registration, not only a `UserDefaults` boolean.
- Failure shows contextual explanatory text and a retry action.

### 9.2 Popover section

Potential controls, only when implemented:

- Toggle: `Show brightness percentage`
- Picker: `Display order` with `Display arrangement` and `Name`

Defaults:

- Percentage shown.
- Display arrangement order.

Do not ship controls that only change cosmetic decoration.

### 9.3 Update section

Absent until a real signed update mechanism exists. Do not show `Automatic updates` as a nonfunctional toggle.

## 10. Displays settings

### 10.1 Display list

The detail view shows connected displays first and remembered disconnected displays in a clearly separated secondary group only when persisted per-display preferences exist.

Each row includes:

- Display name.
- Connected/disconnected state.
- Current control method.
- Current brightness when available.

Selecting a display opens its configuration detail.

### 10.2 Display detail

```text
Dell U2723QE
Connected · Hardware control

Brightness range
Minimum                         10%
Maximum                        100%

Control
Method                      Automatic

[Forget display settings]
```

Controls:

- Minimum brightness: native slider or numeric field/stepper with percentage.
- Maximum brightness: native slider or numeric field/stepper with percentage.
- Control method picker: `Automatic`, `Hardware`, `Software`, `Display shade`.
- `Automatic` is default and recommended.
- Unsupported forced modes remain visible only if the UI can explain why they are unavailable without enabling them.

Validation:

- Minimum cannot exceed maximum.
- The current brightness is clamped only after an explicit user change or confirmation; opening Settings must not alter the monitor.
- Reset/forget is a destructive text button with confirmation only when it removes meaningful saved configuration.

### 10.3 Control method language

User-facing terms:

- `Automatic`
- `Hardware control`
- `Software control`
- `Display shade`

Internal terms such as `ddc`, `gamma`, `overlay`, VCP codes, IOKit services, and private framework names appear only in diagnostics.

## 11. Keyboard settings

Controls may ship only after keyboard handling is implemented and tested.

### 11.1 Brightness keys

- Toggle: `Use brightness keys for external displays`
- Picker: `Target display`
  - `Display under pointer`
  - `All external displays`
  - Individual display names

Default target requires product validation; do not assume all displays should move together.

### 11.2 Custom shortcuts

- `Increase brightness`
- `Decrease brightness`

Requirements:

- Use a proper macOS shortcut recorder/control.
- Reject reserved or conflicting shortcuts with clear inline feedback.
- Render key equivalents using native glyphs.
- Provide a clear button.
- Keyboard handling must not require Accessibility permission unless the chosen system API genuinely requires it; permissions must not be introduced casually.

## 12. Advanced settings

This section is practical recovery tooling, not a laboratory of ordinary preferences.

### 12.1 Detection

Actions:

- `Re-detect displays`
- `Retry hardware control`

Behavior:

- Show progress inline.
- Preserve current user-visible brightness during probing.
- Report result in concise status text.

### 12.2 Diagnostics

Actions:

- `Copy diagnostic summary`
- `Export diagnostic report…`
- `Reveal logs in Finder` only when a real log file exists.

Diagnostic report may include:

- MyMonitor version/build.
- macOS version.
- Mac architecture/model class when available without invasive collection.
- Display identifiers suitable for support.
- Connection/control capability summary.
- Recent non-sensitive errors.

Must exclude:

- Window titles.
- User documents.
- Clipboard data.
- Account information.
- Unrelated system inventory.

### 12.3 Reset

Action:

- `Reset all display preferences…`

Requires a native confirmation alert describing exactly what will be removed. It must not alter current physical brightness until the next explicit user action unless the confirmation states otherwise.

## 13. About settings

Content:

- App icon.
- `MyMonitor`.
- Version and build.
- One-sentence description: `External-monitor brightness control for macOS.`
- `View Source`.
- `Licenses`.
- MonitorControl attribution.
- Privacy statement: local-only, no analytics/network service in the core app.

Do not include a hero banner, changelog feed, newsletter, social buttons, or purchase controls.

## 14. Copy style

### Principles

- Literal, calm, and short.
- Describe the user-visible result before the implementation.
- Sentence case.
- Avoid exclamation marks.
- Avoid marketing adjectives such as magical, gorgeous, blazing, revolutionary, or pro.
- Do not blame the user or monitor.

### Approved terminology

| Use | Avoid in normal UI |
|---|---|
| External display | Screen device, endpoint |
| Brightness | Luminance VCP |
| Hardware control | DDC/CI Tier 1 |
| Software control | Gamma backend |
| Display shade | Overlay backend |
| Re-detect displays | Reconfigure router |
| Brightness unavailable | Probe failure |

### Ellipses

Use an ellipsis only when the action opens another window or requires additional input/confirmation:

- `Preferences…`
- `Export diagnostic report…`
- `Reset all display preferences…`

Do not append ellipses to immediate actions such as `Refresh`, `Retry`, or `Quit`.

## 15. Focus and keyboard order

### Popover

1. First monitor slider.
2. Subsequent monitor sliders.
3. Any contextual info/retry controls in visual order.
4. Preferences.
5. Quit.

### Settings

1. Sidebar selection.
2. Detail view controls in top-to-bottom reading order.
3. Destructive/reset actions last.

Requirements:

- Visible native focus ring.
- No custom keyboard interception that breaks text fields or sliders.
- Tab/Shift-Tab traverse all controls.
- Space activates focused buttons/toggles.
- Return activates the default action only when the window has an intentional default action.
- Escape dismisses sheets/popovers before closing Settings.

## 16. Accessibility semantics

### Status item

- Label: `MyMonitor`
- Help: `Open external display brightness controls.`

### Slider

- Label: `Brightness for <display name>`
- Value: `<integer> percent`
- Hint: `Adjusts external-display brightness.`

### Display status

Combine display name, connection, control method, and error state into a concise VoiceOver reading order. Avoid reading decorative moon/sun symbols.

### Dynamic changes

Announce only meaningful events:

- A display connected or disconnected.
- Brightness control became unavailable.
- Retry succeeded or failed.

Do not announce every slider percentage during pointer dragging beyond native slider behavior.

## 17. Localization and text expansion

- All user-facing strings must be localizable.
- Layout must tolerate at least 30% text expansion.
- Display names may be long and are not controlled by the app.
- Settings rows must not rely on fixed English label widths.
- Percentage and shortcut accessories remain aligned without clipping labels.
- Do not concatenate fragments to form sentences.

## 18. State model required by the frontend

The presentation layer needs explicit, testable states rather than inferring them from empty arrays or backend dictionaries.

Suggested conceptual model:

```swift
enum DisplayPresentationState {
  case detecting(cached: [MonitorPresentation])
  case ready([MonitorPresentation])
  case empty
  case failed(RecoveryPresentation)
}

struct MonitorPresentation: Identifiable, Equatable {
  let id: StableDisplayID
  let name: String
  let connection: ConnectionState
  let control: ControlPresentation
  let brightness: Double?
  let allowedRange: ClosedRange<Double>
}

enum ControlPresentation {
  case checking
  case hardware
  case software
  case shade
  case unavailable(message: String, canRetry: Bool)
}
```

The exact types may differ, but the states and transitions must remain explicit.

## 19. Performance behavior

Frontend budgets:

- Popover presentation must not synchronously wait for DDC reads/writes.
- Status-item click to first visible frame: target under 100 ms on supported hardware, with a stricter aspiration of one main-run-loop turn.
- Pointer-to-thumb visual update: next frame.
- No continuous layout invalidation during slider drag.
- No display enumeration in `body`.
- No repeated creation/destruction of backend objects when only the popover opens/closes.
- Settings should open from cached state and refine asynchronously.

## 20. Analytics and privacy

No analytics events are required to implement or evaluate the frontend. Product quality is validated through deterministic tests, manual QA, issue reports, and opt-in diagnostic exports.

## 21. Acceptance summary

The product UX is correct when a new user can:

1. Install and launch MyMonitor.
2. Click the display icon.
3. Identify every external monitor.
4. Move the correct slider in the expected direction.
5. Understand a fallback without reading technical jargon.
6. Open Preferences and configure a display using familiar Mac controls.
7. Complete the same tasks with keyboard and VoiceOver.
8. Use the app in Light/Dark/Graphite and accessibility appearances without visual breakage.

No tutorial should be necessary.
