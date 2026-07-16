import CoreGraphics
import Foundation

/// User-selected control strategy for one external display.
///
/// `automatic` follows the capability cascade. Forced modes are attempted when the display
/// reconnects or the preference changes; if a connection cannot provide the requested mode,
/// the router remains usable through its automatic fallback and reports the active tier.
enum BrightnessControlPreference: String, Codable, CaseIterable, Sendable {
  case automatic
  case hardware
  case software
  case shade
}

/// Router-owned configuration snapshot used by the frontend adapter.
struct DisplayConfigurationItem: Identifiable, Equatable {
  let id: CGDirectDisplayID
  var name: String
  var isConnected: Bool
  var brightness: Double?
  var allowedRange: ClosedRange<Double>
  var preference: BrightnessControlPreference
  var activeTier: BrightnessTier?
}
