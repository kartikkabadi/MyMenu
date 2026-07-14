import CoreGraphics

/// Shared brightness -> gamma mapping for Tier 2 and overlay Space-transition holds.
enum DisplayGamma {
  private static let minMultiplier: Double = 0.15
  private static let maxMultiplier: Double = 1.0

  @discardableResult
  static func applyBrightness(_ brightness: Double, to displayID: CGDirectDisplayID) -> CGError {
    let t = min(max(brightness, 0), 1)
    let mult = CGGammaValue(minMultiplier + t * (maxMultiplier - minMultiplier))
    return CGSetDisplayTransferByFormula(
      displayID,
      0, mult, 1.0,
      0, mult, 1.0,
      0, mult, 1.0
    )
  }

  static func applyBrightnessHold(
    _ brightness: Double,
    displayID: CGDirectDisplayID,
    includeBuiltin: Bool = false
  ) {
    guard includeBuiltin || CGDisplayIsBuiltin(displayID) == 0 else { return }
    _ = applyBrightness(brightness, to: displayID)
  }

  static func releaseHold(displayID: CGDirectDisplayID, includeBuiltin: Bool = false) {
    guard includeBuiltin || CGDisplayIsBuiltin(displayID) == 0 else { return }
    _ = applyBrightness(1.0, to: displayID)
  }
}
