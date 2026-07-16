import AppKit
import CoreGraphics
import Foundation

/// Per-display gamma dimming (Tier 2) via `CGSetDisplayTransferByFormula`.
@MainActor
final class GammaBrightnessBackend: BrightnessBackend {
  static let tier: BrightnessTier = .gamma

  private struct ActiveState {
    let ownerID: UUID
    var brightness: Double
  }

  /// Slightly off-identity multiplier used only during `probe`.
  private static let probeMultiplier: CGGammaValue = 0.92
  private static let probeTolerance: CGGammaValue = 0.03
  private static var activeStateByDisplay: [CGDirectDisplayID: ActiveState] = [:]

  private let displayID: CGDirectDisplayID
  private let ownerID = UUID()
  private var currentBrightness: Double = 0
  private var tornDown = false

  init(displayID: CGDirectDisplayID) {
    self.displayID = displayID
    guard Self.isExternal(displayID) else { return }
    Self.activeStateByDisplay[displayID] = ActiveState(
      ownerID: ownerID,
      brightness: 1
    )
    _ = DisplayGamma.applyBrightness(1.0, to: displayID)
  }

  static func probe(displayID: CGDirectDisplayID) -> Bool {
    guard isExternal(displayID) else { return false }

    guard CGSetDisplayTransferByFormula(
      displayID,
      0, probeMultiplier, 1.0,
      0, probeMultiplier, 1.0,
      0, probeMultiplier, 1.0
    ) == .success else {
      return false
    }

    // ColorSync restoration is process-global. Restore the calibration, then immediately reapply
    // every gamma backend that remains active so probing one display cannot brighten another.
    defer { restoreColorSyncAndReapplyActiveGamma() }

    var redMin: CGGammaValue = 0
    var redMax: CGGammaValue = 0
    var redGamma: CGGammaValue = 0
    var greenMin: CGGammaValue = 0
    var greenMax: CGGammaValue = 0
    var greenGamma: CGGammaValue = 0
    var blueMin: CGGammaValue = 0
    var blueMax: CGGammaValue = 0
    var blueGamma: CGGammaValue = 0

    guard CGGetDisplayTransferByFormula(
      displayID,
      &redMin, &redMax, &redGamma,
      &greenMin, &greenMax, &greenGamma,
      &blueMin, &blueMax, &blueGamma
    ) == .success else {
      return false
    }

    return abs(redMax - probeMultiplier) <= probeTolerance
  }

  func setBrightness(_ value: Double, animated: Bool) {
    let clamped = min(max(value, 0), 1)
    guard Self.isExternal(displayID),
      !tornDown,
      Self.activeStateByDisplay[displayID]?.ownerID == ownerID
    else {
      return
    }
    guard clamped != currentBrightness else { return }
    _ = animated
    currentBrightness = clamped
    Self.activeStateByDisplay[displayID]?.brightness = clamped
    DisplayGamma.applyBrightnessHold(clamped, displayID: displayID)
  }

  func teardown() {
    guard !tornDown else { return }
    tornDown = true
    guard Self.isExternal(displayID),
      Self.activeStateByDisplay[displayID]?.ownerID == ownerID
    else {
      return
    }

    Self.activeStateByDisplay.removeValue(forKey: displayID)
    Self.restoreColorSyncAndReapplyActiveGamma()
  }

  private static func restoreColorSyncAndReapplyActiveGamma() {
    CGDisplayRestoreColorSyncSettings()
    for (displayID, state) in activeStateByDisplay {
      DisplayGamma.applyBrightnessHold(
        state.brightness,
        displayID: displayID
      )
    }
  }

  private static func isExternal(_ displayID: CGDirectDisplayID) -> Bool {
    CGDisplayIsBuiltin(displayID) == 0
  }
}
