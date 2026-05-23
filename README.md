# MyMenu

macOS menu bar app for **external monitor brightness only**. Matches the One Menu brightness slider UX while trying the best available control path on your hardware.

## Brightness tiers (automatic)

For each external display, MyMenu tries in order:

1. **Hardware (DDC/CI)** — real monitor backlight via I²C (USB-C/DisplayPort setups)
2. **Software gamma** — per-display gamma curve
3. **Screen overlay** — translucent black layer on the external screen only (reliable on HDMI dongles; same class of solution as One Menu)

The active tier is shown under the slider.

## Requirements

- macOS **26.0** or later
- External display connected (built-in screen is never dimmed by this app)

## Install (local build)

```bash
cd ~/Projects/MyMenu
chmod +x scripts/package-local.sh
./scripts/package-local.sh
```

Artifacts:

- `dist/MyMenu.zip`
- `dist/MyMenu.dmg`

Copy to Applications:

```bash
cp -R build/DerivedData/Build/Products/Release/MyMenu.app /Applications/
open /Applications/MyMenu.app
```

If macOS blocks launch after download:

```bash
xattr -dr com.apple.quarantine /Applications/MyMenu.app
```

Or right-click the app → **Open** once.

## HDMI dongle note

USB-C → HDMI adapters on Apple Silicon often **do not support DDC**. MyMenu will typically use **Screen overlay** — this is expected, not a bug. Use USB-C/DisplayPort direct for hardware brightness.

## Enable DDC on your monitor

In the monitor OSD, enable **DDC/CI** if you want Tier 1 hardware control.

## Development

```bash
xcode-select -s /Applications/Xcode.app/Contents/Developer
open MyMenu.xcodeproj
```

## Third-party code

DDC support is adapted from [MonitorControl](https://github.com/MonitorControl/MonitorControl) (MIT). See [MyMenu/ThirdParty/README.md](MyMenu/ThirdParty/README.md).

## License

MIT (application code). Third-party components retain their licenses.
