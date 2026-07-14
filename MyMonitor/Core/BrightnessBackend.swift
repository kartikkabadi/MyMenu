import CoreGraphics
import Foundation

/// Active brightness control mechanism for one external display.
enum BrightnessTier: String, Codable, Sendable {
  case ddc
  case gamma
  case overlay
}

/// Per-display brightness control (DDC, gamma, or overlay).
@MainActor
protocol BrightnessBackend: AnyObject {
  static var tier: BrightnessTier { get }

  init(displayID: CGDirectDisplayID)

  /// Whether this tier can control the given display (e.g. DDC luminance read succeeds).
  static func probe(displayID: CGDirectDisplayID) -> Bool

  /// Normalized brightness: 0 = full bright, 1 = maximum dim.
  /// Pass `animated: false` while the user is dragging for instant feedback.
  func setBrightness(_ value: Double, animated: Bool)

  /// Release resources (windows, gamma state, pending DDC writes).
  func teardown()
}

extension BrightnessBackend {
  func setBrightness(_ value: Double) {
    setBrightness(value, animated: false)
  }
}
