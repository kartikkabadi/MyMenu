# Validation notes

This document records the checks that are useful when validating MyMenu on a real Mac. Hardware brightness behavior varies by monitor, cable, adapter, display mode, and macOS privacy state, so the runtime checks below complement the build check.

## Automated checks

| Check | Result |
| --- | --- |
| `xcodebuild` Debug build | Pass on the development Mac |
| Project generation | Pass with `scripts/generate_xcodeproj.sh` |
| `git diff --check` | Required before publishing |

## Brightness matrix

| Scenario | Expected result |
| --- | --- |
| Direct USB-C/DisplayPort display with DDC/CI enabled | Hardware brightness when supported |
| HDMI dongle without DDC/CI | Screen overlay fallback |
| Extended desktop | External display dims; built-in display remains unchanged |
| Mirrored desktop | The selected external display path remains stable during Space changes |
| Quit MyMenu | Overlay windows are removed and temporary gamma changes are released |

## Window feature matrix

Before testing, grant Accessibility to MyMenu. Also grant Screen Recording for the window switcher.

| Feature | Shortcut | Expected result |
| --- | --- | --- |
| Window snapping | Control-Option + arrow | Focused window moves to the selected layout |
| Window restore | Repeat the same snapping shortcut | The previous window frame is restored |
| Window switcher | Option-Tab | HUD appears and selection advances |
| Reverse switcher | Option-Shift-Tab | HUD appears and selection moves backward |
| Window selection | Release Option | Selected app/window becomes active |
| Recording preview | Enable **Show Dimming in Recordings** | Brightness changes are visible in a full-display recording |

If a shortcut does not fire, check for a macOS or third-party shortcut conflict and confirm the feature is enabled in the MyMenu panel.

For recording preview, use a full-display source for the display that contains the external monitor. A selected-window recording or a recording of a different display cannot include an overlay that belongs to the external display.
