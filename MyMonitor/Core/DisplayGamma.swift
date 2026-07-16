import CoreGraphics

/// Shared brightness-to-gamma mapping for Tier 2 and overlay Space-transition holds.
@MainActor
enum DisplayGamma {
  private static let minMultiplier: Double = 0.15
  private static let maxMultiplier: Double = 1.0
  private static var holds = GammaHoldRegistry<CGDirectDisplayID>()

  @discardableResult
  static func applyBrightness(_ brightness: Double, to displayID: CGDirectDisplayID) -> CGError {
    let t = min(max(brightness, 0), 1)
    let multiplier = CGGammaValue(minMultiplier + t * (maxMultiplier - minMultiplier))
    return CGSetDisplayTransferByFormula(
      displayID,
      0, multiplier, 1.0,
      0, multiplier, 1.0,
      0, multiplier, 1.0
    )
  }

  static func applyBrightnessHold(
    _ brightness: Double,
    displayID: CGDirectDisplayID,
    includeBuiltin: Bool = false
  ) {
    guard includeBuiltin || CGDisplayIsBuiltin(displayID) == 0 else { return }
    holds.setBrightness(brightness, for: displayID)
    guard let clamped = holds.brightnessByID[displayID] else { return }
    _ = applyBrightness(clamped, to: displayID)
  }

  static func releaseHold(
    displayID: CGDirectDisplayID,
    includeBuiltin: Bool = false
  ) {
    guard includeBuiltin || CGDisplayIsBuiltin(displayID) == 0 else { return }
    holds.removeBrightness(for: displayID)
    _ = applyBrightness(1.0, to: displayID)
  }

  /// ColorSync restoration is process-global. Replay every still-owned hold immediately so
  /// restoring one display cannot brighten another gamma backend or a temporary mirror hold.
  static func restoreColorSyncAndReapplyHolds() {
    CGDisplayRestoreColorSyncSettings()
    for (displayID, brightness) in holds.brightnessByID {
      _ = applyBrightness(brightness, to: displayID)
    }
  }
}
