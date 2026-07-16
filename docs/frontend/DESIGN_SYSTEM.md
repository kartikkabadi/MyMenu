# Native macOS Design System

This is a constraint system, not a custom visual brand kit. MyMonitor should inherit macOS 26 behavior and appearance wherever possible.

## 1. Design principles

### 1.1 System first

Before creating any custom view, ask:

1. Is there a native macOS component for this role?
2. Can standard composition solve the hierarchy?
3. Does customization remove behavior such as focus, keyboard, accessibility, appearance adaptation, or future OS styling?
4. Is the visual difference a real product requirement or only aesthetic preference?

A custom component is justified only when the native alternative cannot express a documented requirement.

### 1.2 Content and controls are different layers

- Popover/window/sidebar material forms the floating control or navigation layer.
- Monitor information and preference rows are content.
- Do not apply the same material to both layers.
- Do not create nested glass containers.

### 1.3 Quiet resting state

The interface should gain emphasis through interaction and focus, not permanent decoration.

At rest:

- No glows.
- No animated gradients.
- No colored outlines.
- No oversized icons.
- No excessive cards.
- No custom entrance choreography.

### 1.4 Density appropriate to Mac

macOS is a pointer-and-keyboard environment. Use compact native controls, clear labels, and sensible hit targets. Do not inflate every row to mobile dimensions.

## 2. Component mapping

| Product role | Required platform component | Notes |
|---|---|---|
| Menu-bar presence | `NSStatusItem` / `NSStatusBarButton` | Template SF Symbol, standard hit target. |
| Main transient surface | `NSPopover` | `.transient`, anchored to status item. |
| Brightness input | SwiftUI `Slider` | Do not rebuild track/thumb. |
| Settings window | SwiftUI `Settings` scene or one `NSWindowController` hosting SwiftUI | One window instance. Architecture spike decides host. |
| Settings navigation | `NavigationSplitView` + sidebar `List` | Native selection and resizing. |
| Preference groups | `Form` + `Section` | Avoid custom card backgrounds. |
| Label/value row | `LabeledContent` | Use native alignment. |
| Boolean preference | `Toggle` | Native switch/check style chosen by context. |
| Choice | `Picker` / `Menu` | Native menu behavior and checkmarks. |
| Immediate action | `Button` | Standard or bordered style based on role. |
| Destructive action | `Button(role: .destructive)` | Confirmation when data loss is meaningful. |
| Additional explanation | `help`, native popover, disclosure group, or inline secondary text | Smallest clear method wins. |
| Empty-state progress | `ProgressView` | Only while real work is pending. |
| Separator | `Divider` | Use sparingly. |
| Scroll overflow | `ScrollView` / `List` | System scroll indicators and edge behavior. |
| Confirmation | Native alert/confirmation dialog | No custom modal card. |
| Shortcut capture | Native-compatible recorder component | Must preserve key glyphs and conflict feedback. |
| Launch at login | `SMAppService` backed toggle | UI reflects real system state. |

## 3. Liquid Glass rules

### 3.1 Approved uses

- System-provided popover/window/sidebar/control appearances on macOS 26.
- A custom glass effect only when implementing a truly custom floating control with no native equivalent and after an approved spike.
- Selective tint on a primary action or selection.

### 3.2 Prohibited uses

- `.glassEffect()` on every monitor row.
- `GlassEffectContainer` around ordinary form content.
- Glass backgrounds behind sliders already placed in a material popover.
- Glass on top of glass.
- Mixing Regular and Clear variants.
- Clear glass in v1.
- Manual blur layers that imitate system material.
- A screenshot-derived gradient or border intended to copy OneMenu.

### 3.3 Custom-material exception process

A proposed custom material must document:

1. The missing native behavior.
2. Prototype screenshots in Light, Dark, Increased Contrast, and Reduce Transparency.
3. Keyboard and VoiceOver behavior.
4. Energy/performance impact.
5. Why a standard fill, grouping, separator, or native material cannot solve it.

Without that evidence, use the native component.

## 4. Typography

Use San Francisco through semantic SwiftUI/AppKit styles. Do not bundle or request custom fonts.

### 4.1 Popover type roles

| Role | Semantic style | Additional treatment |
|---|---|---|
| Optional multi-display heading | `.headline` or `.callout.weight(.semibold)` | Must not dominate display names. |
| Display name | `.body.weight(.medium)` or `.callout.weight(.medium)` | One line. |
| Percentage | `.callout` | `.monospacedDigit()`. |
| Control method | `.caption` | Secondary/tertiary foreground. |
| Empty-state title | `.headline` | Centered only in the empty state. |
| Empty-state body | `.callout` | Secondary, maximum two short lines. |
| Footer actions | Native button text | No forced bold. |

### 4.2 Settings type roles

Use native `Form`, `Section`, `LabeledContent`, and sidebar typography. Avoid manual font sizes for ordinary settings rows.

Allowed custom semantic emphasis:

- Page title: system title/headline as produced by navigation/window structure.
- Display detail name: `.title2` or native detail heading, only when it improves orientation.
- Supporting status: `.subheadline`/`.caption`, secondary.

### 4.3 Typography prohibitions

- No manually selected 9, 10, 11, 12, 13 point ladder across dozens of views.
- No rounded design font for branding.
- No tracking/letterspacing for ordinary labels.
- No all-caps `MYMONITOR` eyebrow.
- No text shadow.
- No low-opacity text below system legibility thresholds.

## 5. Color

### 5.1 Semantic palette

Use:

- `.primary`
- `.secondary`
- `.tertiary`
- `.quaternary` only when still legible
- `.accentColor`
- Semantic system red/orange/yellow only for actual error/warning states
- Native separator/background colors inherited from components

### 5.2 Accent behavior

The user's system accent color controls:

- Slider fill/thumb behavior.
- Sidebar selection.
- Toggle state.
- Focus and primary-action tint where the system uses it.

MyMonitor does not force a blue brand accent.

### 5.3 Fixed-color exceptions

A fixed color is permitted only for:

- A future app icon asset.
- A diagnostic visualization with semantic meaning that cannot use system colors.
- A documented compatibility workaround.

Every fixed UI color requires an inline rationale and appearance/accessibility tests.

### 5.4 Prohibitions

- No custom blue gradient.
- No hard-coded dark panel background.
- No white border with low opacity around every group.
- No color used as the sole status signal.
- No different accent color per monitor.

## 6. Geometry and spacing

### 6.1 Principle

Prefer native layout metrics. When custom spacing is necessary, use a small coherent scale rather than arbitrary per-view numbers.

Recommended spacing scale:

| Token | Value | Use |
|---|---:|---|
| `spaceXS` | 4 | Symbol/text micro-gap, tightly related metadata. |
| `spaceS` | 8 | Within a control group. |
| `spaceM` | 12 | Between monitor-row elements or rows. |
| `spaceL` | 16 | Major content inset/section separation when native Form does not manage it. |
| `spaceXL` | 24 | Empty-state vertical separation only. |

Do not expose tokens globally until at least two production components require the same value.

### 6.2 Popover dimensions

- Preferred width: 312.
- Allowed validated range: 300–320.
- Horizontal content inset: 14.
- Top inset: 12.
- Monitor row internal vertical rhythm: 6–8.
- Inter-monitor gap: 12, with a native divider only if testing shows rows blend together.
- Footer vertical padding: native button metrics plus approximately 8–10 points.

### 6.3 Settings dimensions

- Default: 720 × 500.
- Minimum: 620 × 420.
- Native Form spacing and control alignment.
- No fixed-height content cards.
- Detail content gets a readable maximum width when the window becomes very wide rather than stretching labels indefinitely.

### 6.4 Corner radii

The app should own almost no corner-radius constants.

- Popover/window/sidebar: system-managed.
- Form sections: system-managed.
- Buttons/toggles/sliders: system-managed.
- Custom empty-state symbol background is discouraged; if retained after testing, use a native container shape and concentric geometry.

Do not create a general `cardCornerRadius` token.

## 7. Control sizing

### Popover

- Use `.small` or `.regular` native control sizes based on a prototype comparison.
- Slider precision takes precedence over maximum compactness.
- Footer buttons remain easy to target without becoming large capsules.

### Settings

- Use standard macOS control sizes from `Form`.
- Large/X-Large controls are reserved for a genuinely standout primary action; Settings currently has none.

### Hit targets

- Preserve native pointer targets.
- Icon-only disclosure buttons must not become visually tiny click targets.
- Do not expand unrelated text into invisible click regions that surprise users.

## 8. Symbols

Use SF Symbols only.

### Approved symbol vocabulary

| Meaning | Preferred symbol |
|---|---|
| App/status item | `display` |
| Multiple displays | `display.2` |
| Dark end of brightness | `moon` or `sun.min` |
| Bright end | `sun.max` |
| General | `gearshape` |
| Keyboard | `keyboard` |
| Advanced/tools | `wrench.and.screwdriver` |
| About/info | `info.circle` |
| Retry/refresh | `arrow.clockwise` |
| Warning | `exclamationmark.triangle` |
| Error | `xmark.circle` only when the action is impossible |
| Connected | Prefer text; `checkmark.circle` only if needed |

### Symbol rules

- Use hierarchical or monochrome rendering as supplied by the system.
- Do not use multicolor symbols in the core UI.
- Decorative symbols are accessibility-hidden.
- Icon-only controls require labels/help.
- If the meaning is ambiguous, use text.
- Do not design custom SVG versions of SF Symbols.

## 9. Buttons and action hierarchy

### 9.1 Roles

- **Primary:** the one action that advances or resolves the current task. Most MyMonitor surfaces have no persistent primary button.
- **Secondary:** retry, refresh, export, or open diagnostics.
- **Tertiary/plain:** Preferences, Quit, info disclosures.
- **Destructive:** reset/forget operations.

### 9.2 Styles

- Let context choose the native style.
- Avoid globally forcing `.buttonStyle(.plain)` when doing so removes expected hover/focus feedback.
- Avoid custom capsule fills.
- Do not make Quit red in the normal popover footer.
- Destructive red appears only in confirmation/context where data loss is real.

## 10. Sliders

### 10.1 Native requirement

Use SwiftUI's native `Slider` or the underlying AppKit control if a measured platform bug requires it.

Must retain:

- Native pointer interaction.
- Keyboard adjustment.
- Focus ring.
- Accessibility adjustable action.
- System accent/appearance.
- Reduce Motion/contrast behavior.

### 10.2 Presentation

- Continuous `0...1` model, displayed as whole percentages.
- Leading and trailing brightness symbols outside the slider.
- No custom colored track overlay.
- No separate draggable percentage label.
- No tooltip that follows the pointer unless user testing proves it is needed.

### 10.3 Feedback

- Visual thumb/value updates locally and immediately.
- Backend write status does not block pointer feedback.
- A failure produces state/copy, not a custom red slider.

## 11. Toggles, pickers, fields, and menus

- `Toggle` uses system switch style in Settings unless native Form context chooses otherwise.
- Boolean controls do not appear in the popover core path.
- `Picker` uses menu or radio-group behavior appropriate to the number of choices and available width.
- Numeric percentages use native format styles and validation.
- Text fields appear only where free-form input is genuinely required; current v1 Settings needs none except a future shortcut recorder.
- Menus show checkmarks for selected options through native behavior.

## 12. Materials and backgrounds

### Popover

- The `NSPopover` supplies the material shell.
- Root SwiftUI view background is clear/system-managed.
- Rows do not add material.
- A standard fill is allowed for a temporary contextual element only when the native component uses it.

### Settings

- Native window background.
- Native inset sidebar.
- Native Form/group backgrounds.
- No full-window gradient or texture.
- No content bleeding behind sidebar merely to demonstrate `backgroundExtensionEffect`; MyMonitor has no media-rich hero content that justifies it.

## 13. Dividers and grouping

- Layout and whitespace are the first grouping tools.
- Use a divider above the stationary popover footer.
- Between monitor rows, test whitespace first; add a divider only if identity remains unclear.
- Settings sections use native Form grouping.
- Do not wrap every group in a custom rounded rectangle and then add a divider inside it.

## 14. Motion

### Allowed

- Native popover appearance/dismissal.
- Native slider/toggle/menu transitions.
- Short system transition when a display row appears/disappears.
- Crossfade for quiet status text.
- Native sheet/alert presentation.

### Prohibited

- Custom blur-and-scale popover entrance.
- Springing cards.
- Pulsing status icon.
- Animated gradient/background.
- Parallax.
- Continuous material morphing implemented by the app.
- Motion whose only purpose is to advertise Liquid Glass.

### Reduce Motion

All optional transitions must be disabled or simplified when the system Reduce Motion setting is active. State must remain clear without animation.

## 15. Accessibility appearances

### Reduce Transparency

- Native materials become more opaque automatically.
- Content must not depend on seeing the desktop through the surface.
- No text is placed over uncontrolled imagery.
- Custom transparency, if any, must have an explicit opaque fallback.

### Increased Contrast

- Native controls and materials provide stronger boundaries.
- Do not suppress system borders/focus rings.
- Status meaning remains understandable through text/symbols, not subtle opacity alone.

### Differentiate Without Color

- Control method and errors use labels/symbols in addition to color.
- Sidebar selection and toggle state retain native non-color cues.

### VoiceOver

- Decorative symbols hidden.
- Icon-only buttons labeled.
- Slider label includes display name.
- Duplicate percentage text hidden from accessibility when slider value already supplies it.
- Dynamic announcements limited to meaningful connection/control events.

## 16. Appearance matrix

Every frontend ticket that affects visual output must inspect:

1. Light appearance.
2. Dark appearance.
3. Graphite accent.
4. A non-blue accent color.
5. Increased Contrast.
6. Reduce Transparency.
7. Reduce Motion for changed transitions.
8. Active and inactive Settings window.

Do not use screenshots from one appearance as proof of completion.

## 17. Localization and layout resilience

- Semantic fonts support user/system text behavior.
- Avoid fixed label widths except where native `LabeledContent` handles alignment.
- Support 30% string expansion.
- Display names can be substantially longer than example hardware names.
- Use truncation only after preserving control/value visibility.
- Tooltips/help text must be localizable.
- Symbols do not replace text that translators need to convey meaning.

## 18. Preview and visual-test fixtures

Frontend views should support deterministic preview fixtures without live display APIs:

- No displays.
- One DDC display at 72%.
- One software-controlled display.
- One shade-controlled display.
- Two displays with long names.
- Four displays causing scrolling.
- Checking control method.
- Unavailable control with retry.
- Light/Dark and accessibility environment variants.

Preview fixtures are presentation data, not mock backend implementations embedded in views.

## 19. Review checklist for custom UI

Any new custom view must answer in its pull request:

- What platform role does it implement?
- Which native component was considered?
- Which requirement could not be met natively?
- Does it preserve keyboard focus and VoiceOver?
- Does it adapt to system accent and appearance?
- Does it work with Reduce Transparency/Contrast/Motion?
- Is its geometry concentric with its container?
- Is it still necessary after removing decorative background/border/shadow?

If these answers are weak, delete the custom view.
