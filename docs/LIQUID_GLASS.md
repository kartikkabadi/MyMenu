# Liquid Glass UI — One Menu parity

## Shell (matches One Menu binary)

- **`NSStatusItem` + `NSPopover`** via [`PopoverWindowController`](../MyMenu/PopoverWindowController.swift) — not `MenuBarExtra`.
- **`popoverWillShow`**: clear popover window, bump `PopoverAnimationToken.contentGeneration` (Recreate pattern), reinstall `NSHostingController`.
- **Appear every open**: [`PopoverAppearModifier`](../MyMenu/Design/PopoverAppearModifier.swift) driven by `appearGeneration` + fresh view `id` — not one-shot `onAppear` on a persistent host.

## Glass layout

- **Panel**: `.glassEffect(.regular.interactive())` on background `RoundedRectangle` only — controls sit above, not inside stacked glass.
- **Quit**: `.glassProminent` + `BrightnessDesign.quitTint` (blue) + white label; action via `AppDelegate.quitApp()` (close popover → teardown → terminate).
- **Slider**: system `Slider` + hierarchical moon/sun icons.

## Overlay + fullscreen video Spaces (mirror mode)

When `NSScreen.screens.count == 1` (mirrored desktop) and tier is **overlay**:

1. **Space transition start** (`activeSpaceDidChange`, etc.): apply **gamma hold** via [`DisplayGamma`](../MyMenu/Core/DisplayGamma.swift) at current brightness; suppress overlay `orderFront`; reaffirm shade alpha only.
2. **~550ms later**: release gamma hold; single `finalizeAfterSpaceTransition()` (frame sync + one order-front).
3. Overlay panel uses **`NSPanel` at `.floating`** + `.fullScreenAuxiliary` (not `maximumWindow`).

This avoids the “flash bang” when swiping to Safari native fullscreen video Spaces while keeping normal desktop Spaces stable.

## Desk-test checklist

| Action | Expected |
|--------|----------|
| Open popover repeatedly | Appear animation every time |
| Quit button | Blue button, white text, app exits |
| Swipe L/R normal ↔ normal Space | Dim persists, no flash |
| Swipe L/R ↔ Netflix fullscreen Space | No full-brightness flash |
| Mission Control (3-finger up) | No regression |
