import Foundation

extension DisplayPresentationStore {
  /// Apply one persisted keyboard step while preserving the same optimistic reconciliation used
  /// by direct slider manipulation.
  func adjustBrightness(by delta: Double, for monitorID: MonitorID) {
    guard let brightness = monitor(withID: monitorID)?.brightness else { return }

    beginBrightnessAdjustment(for: monitorID)
    updateBrightness(brightness + delta, for: monitorID)
    endBrightnessAdjustment(for: monitorID)
  }
}
