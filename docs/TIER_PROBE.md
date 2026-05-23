# Phase 0 — Tier probe (M1 Pro + LG L22e-40)

**Machine:** Apple M1 Pro, macOS 26.5  
**External:** LG L22e-40 (1920×1080)  
**Connection:** USB-C → HDMI dongle  
**Display modes tested:** Extended and mirrored (both required by plan)

## Expected results (from prior research + hardware path)

| Tier | Mechanism | Expected on this setup |
|------|-----------|-------------------------|
| **1 — DDC/CI** | `IOAVService` I²C, VCP `0x10` | **Likely fail** — HDMI dongles often strip DDC on M1 |
| **2 — Gamma** | `CGSetDisplayTransferByFormula` per display | **Often fail or unreliable** in mirror mode / HDR |
| **3 — Overlay** | Per-external `NSWindow`, black + opacity | **Expected active tier** — same class as One Menu |

## Runtime probe (MyMenu)

MyMenu probes at display connect:

1. `DDCBrightnessBackend.probe` — Arm64DDC read luminance  
2. `GammaBrightnessBackend.probe` — apply + verify transfer  
3. `OverlayBrightnessBackend` — always available fallback  

Persisted per display UUID in `UserDefaults` (`activeTier`).

## Validation checklist

- [ ] Extended: slider dims **external only**; built-in unchanged  
- [ ] Mirrored: slider dims **external only**; built-in unchanged  
- [ ] Tier label shows **Screen overlay** on dongle setup  
- [ ] Quit removes overlay / restores gamma  

## Notes

Enable **DDC/CI** in LG OSD if testing hardware tier. USB-C/DisplayPort direct may unlock Tier 1 without app update.
