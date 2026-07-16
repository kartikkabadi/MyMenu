# MyMonitor

MyMonitor is a focused, native macOS menu-bar app for controlling external-display brightness.

It has one job: detect connected monitors, choose the best available control method, and make brightness adjustment feel like a built-in macOS control.

## Product scope

- **Per-monitor brightness** for every connected external display.
- **Hardware DDC/CI** when the monitor and connection support it.
- **Software gamma** when hardware control is unavailable.
- **Display shade fallback** for connections such as HDMI dongles that expose neither DDC nor usable gamma control.
- **Local-only preferences** in `UserDefaults`.

MyMonitor does not include window management, an Alt-Tab replacement, accounts, analytics, cloud storage, or network services.

## Frontend specification

The canonical native macOS frontend contract lives in [`docs/frontend/`](docs/frontend/README.md). It includes the research basis, full popover and Settings interaction specification, native component/design rules, binding decisions, sequential implementation tickets, and objective QA matrix.

Frontend work must follow that contract one ticket at a time. It must use real macOS components and system behavior rather than custom glass cards, fixed visual styling, or placeholder features.

## Requirements

- macOS **26.0 or later**
- Apple Silicon Mac
- Xcode **26** for development
- At least one external display

The DDC path uses private macOS display interfaces adapted from MonitorControl. It may require maintenance after macOS updates. The gamma and display-shade tiers remain available when DDC is unsupported.

## Build from source

```bash
git clone https://github.com/kartikkabadi/MyMonitor.git
cd MyMonitor
./scripts/build.sh
```

Or generate and open the Xcode project:

```bash
./scripts/generate_xcodeproj.sh
open MyMonitor.xcodeproj
```

The native app target has no package-manager dependencies. Swift files under `MyMonitor/` are discovered by `scripts/generate_xcodeproj.sh`.

## Validation

```bash
./scripts/generate_xcodeproj.sh
xcodebuild \
  -project MyMonitor.xcodeproj \
  -scheme MyMonitor \
  -configuration Debug \
  -sdk macosx \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

Every pull request is also built with Xcode 26 in GitHub Actions.

Brightness behavior must be tested on real hardware because DDC support depends on the monitor, cable, dock, and adapter. Useful bug reports include the Mac model, macOS version, monitor model, connection path, selected control tier, and exact reproduction steps.

## Distribution status

Current builds are development artifacts. A public release should be Developer ID signed, notarized, stapled, and accepted by Gatekeeper. MyMonitor must not remove macOS quarantine metadata to bypass that trust path.

## Privacy

Brightness control requires no Accessibility or Screen Recording permission. MyMonitor does not transmit display information or usage data.

## Third-party code and license

DDC support is adapted from [MonitorControl](https://github.com/MonitorControl/MonitorControl) under the MIT License. Attribution and license text are in [MyMonitor/ThirdParty/README.md](MyMonitor/ThirdParty/README.md).

MyMonitor is released under the [MIT License](LICENSE). Third-party components retain their original licenses and notices.
