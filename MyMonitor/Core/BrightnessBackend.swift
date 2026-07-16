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

  /// Whether this tier can control the given display (for example, a DDC luminance read succeeds).
  static func probe(displayID: CGDirectDisplayID) -> Bool

  /// Normalized user-facing brightness: 0 = darkest, 1 = brightest.
  /// Every backend must preserve this invariant so switching control tiers never reverses the UI.
  /// Pass `animated: false` while the user is dragging for immediate feedback.
  func setBrightness(_ value: Double, animated: Bool)

  /// Release resources (windows, gamma state, pending DDC writes).
  func teardown()
}

extension BrightnessBackend {
  func setBrightness(_ value: Double) {
    setBrightness(value, animated: false)
  }
}
