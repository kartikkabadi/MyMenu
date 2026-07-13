# Brightness tier probe

The exact tier depends on the Mac, monitor, cable, adapter, display mode, and monitor OSD settings. The HDMI-dongle case below is a representative probe, not a guarantee for every setup.

## Expected results (from prior research + hardware path)

| Tier | Mechanism | Expected on this setup |
|------|-----------|-------------------------|
| **1 — DDC/CI** | `IOAVService` I²C, VCP `0x10` | **Likely fail** — HDMI dongles often strip DDC on M1 |
| **2 — Gamma** | `CGSetDisplayTransferByFormula` per display | **Often fail or unreliable** in mirror mode / HDR |
| **3 — Overlay** | Per-external `NSWindow`, black + opacity | **Expected active tier** — same class as One Menu |

## Runtime probe

MyMenu probes at display connect:

1. `DDCBrightnessBackend.probe` — Arm64DDC read luminance  
2. `GammaBrightnessBackend.probe` — apply + verify transfer  
3. `OverlayBrightnessBackend` — always available fallback  

Persisted per display UUID in `UserDefaults` (`activeTier`).

Gamma and hardware brightness can be invisible to screen capture because they are applied after macOS renders the pixels. Enable **Show Dimming in Recordings** for a session-only overlay when recording a demo.

## Validation checklist

- [ ] Extended: slider dims **external only**; built-in unchanged  
- [ ] Mirrored: slider dims **external only**; built-in unchanged  
- [ ] Tier label shows **Screen overlay** on dongle setup  
- [ ] Quit removes overlay / restores gamma  

## Notes

Enable **DDC/CI** in LG OSD if testing hardware tier. USB-C/DisplayPort direct may unlock Tier 1 without app update.
