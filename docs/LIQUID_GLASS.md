# Interface notes

MyMonitor uses an AppKit status item and a keyable panel so the menu bar experience stays lightweight and can recreate the SwiftUI content on each open.

## Panel behavior

- The panel uses a compact two-section layout: external-display brightness first, optional window controls second.
- macOS 26 uses material-backed cards and the system `Slider`.
- Older supported SDK paths use the custom SwiftUI slider in `ExternalBrightnessSlider`.
- Permission warnings are shown inline beside the feature that needs them.
- **Show Dimming in Recordings** enables a session-only overlay for demos when the selected tier changes pixels after macOS capture.
- The Quit action tears down overlays, gamma holds, hot-key handlers, and window-management monitors before terminating.

## Display transitions

Overlay-backed displays can move or change Spaces while the app remains alive. `DisplayRouter` keeps overlay backends alive during layout churn, suppresses redundant ordering during a transition, and performs one final layout sync after the transition settles. Mirrored displays use a temporary gamma hold to reduce flashes while overlay windows are being repositioned.

## Window controls

Window snapping uses the Accessibility API and converts between AppKit and Accessibility coordinate systems using the primary desktop bounds. The switcher uses Core Graphics window metadata to build its list, then uses Accessibility to focus the selected window after activating its app.
