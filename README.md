# MyMonitor

MyMonitor is a small, local-first macOS menu-bar utility for external-display brightness. It uses the best available control path for each display and leaves the built-in display untouched.

It also includes two opt-in window tools: window snapping and an Option–Tab switcher. The app explains both features during first-run onboarding and asks for macOS privacy access only when you enable them.

## What it does

- **External brightness:** DDC/CI hardware control, then software gamma, then a screen overlay fallback.
- **Window snapping:** `Control-Option-Left/Right` snaps the focused window; Up/Down maximizes or centers it.
- **Option–Tab switcher:** cycles through visible windows and selects on Option release.
- **Recording preview:** adds a capture-visible dimming overlay for product demos.
- **Local-first:** no account, analytics, network service, or cloud storage. Preferences live in `UserDefaults`.

## Requirements

- macOS **26.0 or later**
- Xcode **26** for development
- An external display for brightness control

The DDC path uses private macOS display interfaces and may need maintenance after future macOS updates. MyMonitor does not bypass privacy controls.

## Build from source

```bash
git clone https://github.com/kartikkabadi/MyMenu.git MyMonitor
cd MyMonitor
./scripts/build.sh
```

The project is dependency-free. `scripts/generate_xcodeproj.sh` discovers every Swift file under `MyMonitor/`, so adding a source file does not require Xcode project bookkeeping.

Open `MyMonitor.xcodeproj` if you want to run from Xcode. For a local release package:

```bash
./scripts/package-local.sh
```

This creates `dist/MyMonitor.zip` and `dist/MyMonitor.dmg`. Both contain `Install MyMonitor.command`, which copies the app to `/Applications` (or `~/Applications` when needed), removes the quarantine flag from this locally built package, and launches the app. It does not grant Accessibility or Screen Recording access for you.

Local releases are ad hoc signed and not notarized because notarization requires a paid Apple Developer account. Review the source before running any build.

## Fresh permissions test

To remove this app's saved preferences and TCC entries before testing onboarding again:

```bash
./scripts/reset-permissions.sh
```

Brightness control does not need special privacy access. Optional window tools use:

- **Accessibility** to move, resize, and focus windows.
- **Screen Recording** to read the window list used by the switcher.

If Screen Recording is missing, MyMonitor opens the correct System Settings pane. Bring the app back to the front after granting access so the status refreshes.

For a repeatable recording demo:

```bash
MYMONITOR_SCREEN_RECORDING_PREVIEW=1 /Applications/MyMonitor.app/Contents/MacOS/MyMonitor
```

## Website and Whop checkout

The landing page lives in `website/` and is served by the Cloudflare Worker in `worker.js`. The `/buy` route redirects to a Whop checkout URL held as a Worker secret, so the checkout URL never needs to be committed to the open-source repository.

```bash
wrangler secret put WHOP_CHECKOUT_URL
./scripts/deploy-site.sh
```

`scripts/deploy-site.sh` also refuses to deploy when `WHOP_CHECKOUT_URL` is missing. If you only want to preview the static page locally, serve `website/` with any static file server.

## Development checks

```bash
./scripts/build.sh
git diff --check
```

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and [docs/DESK_TEST_RESULTS.md](docs/DESK_TEST_RESULTS.md) for contribution and real-Mac validation notes.

## Third-party code and license

DDC support is adapted from [MonitorControl](https://github.com/MonitorControl/MonitorControl) under the MIT License. Attribution and license text are in [MyMonitor/ThirdParty/README.md](MyMonitor/ThirdParty/README.md).

MyMonitor is released under the [MIT License](LICENSE). Third-party components retain their original licenses and notices.
