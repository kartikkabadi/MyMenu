#!/usr/bin/env python3
from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one match, found {count}")
    path.write_text(text.replace(old, new, 1))


router = Path("MyMonitor/Core/DisplayRouter.swift")
contract = Path("scripts/validate_backend_concurrency.sh")

replace_once(
    router,
    """  /// Update one display. Drag updates stay in memory; the final value is persisted on release.
  func setBrightness(
    _ value: Double,
    for displayID: CGDirectDisplayID,
    animated: Bool = false,
    persist: Bool = true
  ) {
    guard !hasTornDown else { return }
    let allowedRange = displays.first(where: { $0.id == displayID })?.allowedRange ?? 0...1
    let clamped = min(
      max(value, allowedRange.lowerBound),
      allowedRange.upperBound
    )
    backends[displayID]?.setBrightness(clamped, animated: animated)

    if let index = displays.firstIndex(where: { $0.id == displayID }) {
      displays[index].brightness = clamped
      rememberDisplay(displayID, name: displays[index].name)
    }
    if persist {
      persistBrightness(clamped, displayID: displayID)
    }
  }
""",
    """  /// Update one display. A collapsed full-mirror row fans the same requested value out to every
  /// connected external member; each display still clamps and persists against its own range.
  func setBrightness(
    _ value: Double,
    for displayID: CGDirectDisplayID,
    animated: Bool = false,
    persist: Bool = true
  ) {
    guard !hasTornDown else { return }

    let mirroredIDs = Set(
      displays.compactMap { item in
        CGDisplayIsInMirrorSet(item.id) != 0 ? item.id : nil
      }
    )
    let targetIDs = DisplayReconfigurationPolicy.controlIDs(
      connected: displays.map(\.id),
      mirrored: mirroredIDs,
      selected: displayID,
      isFullMirror: Self.isMirrorMode
    )

    for targetID in targetIDs {
      let allowedRange = displays.first(where: { $0.id == targetID })?.allowedRange ?? 0...1
      let clamped = min(
        max(value, allowedRange.lowerBound),
        allowedRange.upperBound
      )
      backends[targetID]?.setBrightness(clamped, animated: animated)

      if let index = displays.firstIndex(where: { $0.id == targetID }) {
        displays[index].brightness = clamped
        rememberDisplay(targetID, name: displays[index].name)
      }
      if persist {
        persistBrightness(clamped, displayID: targetID)
      }
    }
  }
""",
    "full-mirror brightness fan-out",
)

text = contract.read_text()
anchor = """grep -q 'DisplayReconfigurationPolicy.presentationIDs' "$ROUTER" \\
  || fail "Mirror presentation must distinguish full mirroring from partial mirroring."
"""
addition = anchor + """grep -q 'DisplayReconfigurationPolicy.controlIDs' "$ROUTER" \\
  || fail "A collapsed full-mirror row must control every connected external mirror member."
"""
if text.count(anchor) != 1:
    raise RuntimeError(f"mirror contract anchor: expected one match, found {text.count(anchor)}")
contract.write_text(text.replace(anchor, addition, 1))

print("Applied full-mirror brightness control fan-out.")
