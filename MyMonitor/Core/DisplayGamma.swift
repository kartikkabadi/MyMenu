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
    releaseHolds([displayID], includeBuiltin: includeBuiltin)
  }

  /// Remove a related hold set with one global ColorSync restore. Writing an identity curve is not
  /// sufficient because it can discard the display's calibrated transfer state.
  static func releaseHolds<S: Sequence>(
    _ displayIDs: S,
    includeBuiltin: Bool = false
  ) where S.Element == CGDirectDisplayID {
    let releasable = displayIDs.filter { includeBuiltin || CGDisplayIsBuiltin($0) == 0 }
    guard !releasable.isEmpty else { return }
    holds.removeBrightness(for: releasable)
    restoreColorSyncAndReapplyHolds()
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
