import CoreGraphics
import Foundation
import Observation

/// The only frontend-facing adapter for the existing display router.
///
/// Core Graphics identities, backend tiers, discovery, writes, and persistence stop here.
@MainActor
final class DisplayRouterAdapter: MonitorControlling {
  private let router: DisplayRouter
  private var snapshotHandler: (@MainActor (DisplayControllerSnapshot) -> Void)?

  init(router: DisplayRouter) {
    self.router = router
    observeRouter()
  }

  var currentSnapshot: DisplayControllerSnapshot {
    .ready(router.presentationDisplays.map(Self.makeSnapshot))
  }

  func setSnapshotHandler(
    _ handler: @escaping @MainActor (DisplayControllerSnapshot) -> Void
  ) {
    snapshotHandler = handler
  }

  func refresh() {
    router.reconfigure()
    publishSnapshot()
  }

  func setBrightness(
    _ value: Double,
    for monitorID: MonitorID,
    animated: Bool,
    persist: Bool
  ) {
    router.setBrightness(
      value,
      for: CGDirectDisplayID(monitorID.rawValue),
      animated: animated,
      persist: persist
    )
    publishSnapshot()
  }

  func retryControl(for monitorID: MonitorID) {
    _ = monitorID
    router.reconfigure()
    publishSnapshot()
  }

  func teardown() {
    router.teardownAll()
  }

  private func observeRouter() {
    withObservationTracking {
      _ = router.presentationDisplays.map {
        ($0.id, $0.name, $0.brightness, $0.tier)
      }
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        self.publishSnapshot()
        self.observeRouter()
      }
    }
  }

  private func publishSnapshot() {
    snapshotHandler?(currentSnapshot)
  }

  private static func makeSnapshot(_ item: ExternalDisplayItem) -> MonitorSnapshot {
    MonitorSnapshot(
      id: MonitorID(rawValue: item.id),
      name: item.name,
      brightness: item.brightness,
      control: .available(item.tier.presentationMethod)
    )
  }
}

private extension BrightnessTier {
  var presentationMethod: MonitorControlMethod {
    switch self {
    case .ddc: .hardware
    case .gamma: .software
    case .overlay: .shade
    }
  }
}
