# MyMenu

MyMenu is a small macOS menu bar utility for controlling the brightness of external displays. It uses the best available control path for each display and keeps the built-in display untouched.

> Early open-source release. External-display brightness is the stable core. Window snapping and the Alt-Tab switcher are included as experimental features and depend on macOS privacy permissions.

## What it does

- **Hardware brightness (DDC/CI):** writes the monitor's luminance value when the display and connection expose DDC.
- **Software gamma:** applies a per-display gamma multiplier when hardware brightness is unavailable.
- **Screen overlay:** dims the external display with a translucent overlay as a reliable fallback, including common HDMI-dongle setups.
- **Recording preview:** temporarily adds a visible overlay so dimming is present in screen recordings even when the active tier is gamma or hardware brightness.
- **Window snapping (experimental):** `Control-Option-Left/Right` snaps the focused window to a half and `Control-Option-Up/Down` maximizes or centers it.
- **Window switcher (experimental):** `Option-Tab` and `Option-Shift-Tab` cycle through visible windows and select on Option release.

The app does not use an account, network service, analytics, or cloud storage. Display preferences are stored locally in `UserDefaults`.

## Requirements

- macOS **26.0 or later**
- Xcode **26** for development
- An external display for brightness control

DDC support is implemented for Apple Silicon through the adapted MonitorControl bridge. Gamma and overlay fallbacks can still be used when DDC is unavailable.

The DDC path uses private macOS display interfaces, so it may need maintenance after future macOS updates. MyMenu does not bypass macOS privacy controls.

## Build and run

```bash
git clone https://github.com/kartikkabadi/MyMenu.git
cd MyMenu
./scripts/generate_xcodeproj.sh
open MyMenu.xcodeproj
```

Select the `MyMenu` scheme and run it from Xcode. For a local Release package:

```bash
./scripts/package-local.sh
```

The package script creates `dist/MyMenu.zip` and, when available, `dist/MyMenu.dmg`. Local builds are ad hoc signed and are not notarized. Open a locally built app from Finder with Control-click → **Open** if macOS asks for confirmation.

## Privacy permissions

Brightness control does not require special privacy permissions. The optional window features do:

- **Accessibility:** required to move, resize, and focus windows.
- **Screen Recording:** required for macOS to provide the window list used by the switcher.

Enable each feature in the MyMenu panel, then follow the macOS prompt. If a permission was granted after the app was running, bring MyMenu to the front or restart it so the status refreshes.

### Recording a demo

Screen recording captures macOS-rendered pixels. Hardware brightness and gamma can change the physical display after those pixels are captured, so a recording may look unchanged even while the monitor visibly dims. Enable **Show Dimming in Recordings** in the MyMenu panel before recording. MyMenu adds a capture-visible overlay for the session; disable it afterward for normal brightness behavior.

For a repeatable demo launch, the same mode can be enabled without clicking the panel:

```bash
MYMENU_SCREEN_RECORDING_PREVIEW=1 /Applications/MyMenu.app/Contents/MacOS/MyMenu
```

## Display behavior

For each external display, MyMenu probes these tiers in order:

1. DDC/CI hardware luminance
2. Software gamma
3. Screen overlay

USB-C → HDMI adapters often do not pass DDC/CI. That is expected; MyMenu should fall back to the overlay tier. For hardware control, enable DDC/CI in the monitor's on-screen display and try a direct USB-C/DisplayPort connection.

## Development

The project is intentionally dependency-free. Swift sources are discovered by `scripts/generate_xcodeproj.sh`, so adding a Swift file under `MyMenu/` is enough for the generated project to include it.

Useful local checks:

```bash
xcodebuild -project MyMenu.xcodeproj \
  -scheme MyMenu \
  -configuration Debug \
  -sdk macosx \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contribution workflow and [SECURITY.md](SECURITY.md) for responsible security reports.

## Third-party code

DDC support is adapted from [MonitorControl](https://github.com/MonitorControl/MonitorControl) under the MIT License. The attribution and license text are in [MyMenu/ThirdParty/README.md](MyMenu/ThirdParty/README.md).

## License

MyMenu is released under the [MIT License](LICENSE). Third-party components retain their original licenses and notices.
