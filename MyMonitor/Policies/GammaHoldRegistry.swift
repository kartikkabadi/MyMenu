import Foundation

/// Hardware-free ownership state for gamma curves that must survive a global ColorSync restore.
struct GammaHoldRegistry<ID: Hashable> {
  private(set) var brightnessByID: [ID: Double] = [:]

  mutating func setBrightness(_ value: Double, for id: ID) {
    brightnessByID[id] = min(max(value, 0), 1)
  }

  mutating func removeBrightness(for id: ID) {
    brightnessByID.removeValue(forKey: id)
  }
}
