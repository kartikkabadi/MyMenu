# Desk test results (automated smoke + environment)

**Date:** 2026-05-23  
**Build:** MyMenu 0.1.0 (Release)  
**Host:** M1 Pro, macOS 26.5, LG L22e-40 via USB-C→HDMI  

## Automated checks

| Check | Result |
|-------|--------|
| `xcodebuild` Release | PASS |
| Ad-hoc codesign | PASS |
| `dist/MyMenu.zip` | Created |
| `dist/MyMenu.dmg` | Created |
| App launch (`open MyMenu.app`) | Process running after launch |

## Tier probe (expected)

| Tier | Expected on HDMI dongle |
|------|-------------------------|
| DDC/CI | Fail (adapter) |
| Gamma | May fail in mirror mode |
| Overlay | **Active** |

See [TIER_PROBE.md](TIER_PROBE.md).

## Manual verification (user)

1. Click menu bar sun icon → panel shows **External Monitor Brightness** and tier label.
2. Drag slider → external monitor dims; **built-in unchanged**.
3. Repeat in **mirrored** and **extended** display modes.
4. Quit → overlay removed (no leftover dim layer).

## Artifacts

- `dist/MyMenu.dmg`
- `dist/MyMenu.zip`
