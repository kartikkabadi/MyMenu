import CoreGraphics

/// Shared brightness → gamma mapping for Tier 2 and overlay Space-transition holds.
enum DisplayGamma {
  private static let minGamma: CGGammaValue = 0.3
  private static let maxGamma: CGGammaValue = 1.0

  static func gamma(forBrightness value: Double) -> CGGammaValue {
    let t = Float(min(max(value, 0), 1))
    return maxGamma - t * (maxGamma - minGamma)
  }

  @discardableResult
  static func applyGamma(_ gamma: CGGammaValue, to displayID: CGDirectDisplayID) -> CGError {
    CGSetDisplayTransferByFormula(
      displayID,
      0, 1, gamma,
      0, 1, gamma,
      0, 1, gamma
    )
  }

  static func applyBrightnessHold(_ brightness: Double, displayID: CGDirectDisplayID) {
    guard CGDisplayIsBuiltin(displayID) == 0 else { return }
    _ = applyGamma(gamma(forBrightness: brightness), to: displayID)
  }

  static func releaseHold(displayID: CGDirectDisplayID) {
    guard CGDisplayIsBuiltin(displayID) == 0 else { return }
    _ = applyGamma(maxGamma, to: displayID)
  }
}
