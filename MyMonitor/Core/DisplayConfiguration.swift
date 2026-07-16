import CoreGraphics
import Foundation

/// User-selected control strategy for one external display.
///
/// `automatic` follows the capability cascade. Forced modes are accepted only when the
/// current connection supports them; display shade is always available as the final fallback.
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
  var supportedPreferences: Set<BrightnessControlPreference>
}
