import Foundation

/// Narrow intent boundary between presentation state and display-control infrastructure.
///
/// Implementations own display discovery, capability probing, writes, persistence, and lifecycle.
/// SwiftUI views must never depend on a concrete implementation.
@MainActor
protocol MonitorControlling: AnyObject {
  var currentSnapshot: DisplayControllerSnapshot { get }

  func setSnapshotHandler(
    _ handler: @escaping @MainActor (DisplayControllerSnapshot) -> Void
  )

  func refresh()

  func setBrightness(
    _ value: Double,
    for monitorID: MonitorID,
    animated: Bool,
    persist: Bool
  )

  func retryControl(for monitorID: MonitorID)
  func retryAllControls()
  func teardown()
}

extension MonitorControlling {
  /// Controllers without a narrower all-display probe can use their normal refresh path.
  func retryAllControls() {
    refresh()
  }
}
