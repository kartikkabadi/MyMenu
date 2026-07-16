import CoreGraphics
import Foundation

/// Active brightness control mechanism for one external display.
enum BrightnessTier: String, Codable, Sendable {
  case ddc
  case gamma
  case overlay
}

/// Per-display brightness control (DDC, gamma, or overlay).
///
/// Capability discovery is intentionally outside this protocol. Slow probes must complete before
/// a backend is installed, rather than blocking construction or the main actor.
@MainActor
protocol BrightnessBackend: AnyObject {
  static var tier: BrightnessTier { get }

  init(displayID: CGDirectDisplayID)

  /// Normalized user-facing brightness: 0 = darkest and 1 = brightest.
  /// Every backend preserves this invariant so switching control tiers never reverses the UI.
  func setBrightness(_ value: Double, animated: Bool)

  /// Release resources (windows, gamma state, pending DDC writes).
  func teardown()
}

extension BrightnessBackend {
  func setBrightness(_ value: Double) {
    setBrightness(value, animated: false)
  }
}
