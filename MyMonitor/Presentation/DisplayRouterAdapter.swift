import CoreGraphics
import Foundation
import Observation

/// The only frontend-facing adapter for the existing display router.
///
/// Core Graphics identities, backend tiers, discovery, writes, persistence, and configuration
/// stop here.
@MainActor
final class DisplayRouterAdapter: MonitorControlling, DisplayConfigurationControlling {
  private let router: DisplayRouter
  private var snapshotHandler: (@MainActor (DisplayControllerSnapshot) -> Void)?
  private var configurationHandler: (@MainActor ([MonitorConfigurationSnapshot]) -> Void)?

  init(router: DisplayRouter) {
    self.router = router
    observeRouter()
  }

  var currentSnapshot: DisplayControllerSnapshot {
    let snapshots = router.presentationDisplays.map(Self.makeSnapshot)
    if router.isReconfiguring {
      return .detecting(cached: snapshots)
    }
    return .ready(snapshots)
  }

  var currentConfigurations: [MonitorConfigurationSnapshot] {
    router.configurationDisplays.map(Self.makeConfigurationSnapshot)
  }

  func setSnapshotHandler(
    _ handler: @escaping @MainActor (DisplayControllerSnapshot) -> Void
  ) {
    snapshotHandler = handler
  }

  func setConfigurationHandler(
    _ handler: @escaping @MainActor ([MonitorConfigurationSnapshot]) -> Void
  ) {
    configurationHandler = handler
  }

  func refresh() {
    router.reconfigure(force: true)
    publishAll()
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
    publishAll()
  }

  func retryControl(for monitorID: MonitorID) {
    _ = monitorID
    router.reconfigure(force: true)
    publishAll()
  }

  func retryAllControls() {
    router.reconfigure(force: true)
    publishAll()
  }

  func setBrightnessRange(
    _ range: ClosedRange<Double>,
    for monitorID: MonitorID
  ) {
    router.setBrightnessRange(
      range,
      for: CGDirectDisplayID(monitorID.rawValue)
    )
    publishAll()
  }

  func setControlPreference(
    _ preference: MonitorControlPreference,
    for monitorID: MonitorID
  ) {
    // DisplayRouter starts a new forced generation for control-method changes itself.
    router.setControlPreference(
      preference.backendPreference,
      for: CGDirectDisplayID(monitorID.rawValue)
    )
    publishAll()
  }

  func forgetConfiguration(for monitorID: MonitorID) {
    let wasConnected = currentConfigurations.first { $0.id == monitorID }?.isConnected == true
    router.forgetDisplayConfiguration(
      for: CGDirectDisplayID(monitorID.rawValue)
    )
    if wasConnected {
      // Forgetting resets the requested method to Automatic. Re-probe now so the active backend
      // cannot remain on a previously forced Hardware, Software, or Shade implementation.
      router.reconfigure(force: true)
    }
    publishAll()
  }

  func resetAllConfigurations() {
    let configurations = currentConfigurations
    for monitorID in configurations.map(\.id) {
      router.forgetDisplayConfiguration(
        for: CGDirectDisplayID(monitorID.rawValue)
      )
    }
    if configurations.contains(where: \.isConnected) {
      router.reconfigure(force: true)
    }
    publishAll()
  }

  func teardown() {
    router.teardownAll()
  }

  private func observeRouter() {
    withObservationTracking {
      _ = router.isReconfiguring
      _ = router.presentationDisplays.map {
        (
          $0.id,
          $0.name,
          $0.brightness,
          $0.tier,
          $0.allowedRange.lowerBound,
          $0.allowedRange.upperBound,
          $0.controlPreference
        )
      }
      _ = router.configurationDisplays.map {
        (
          $0.id,
          $0.name,
          $0.isConnected,
          $0.brightness,
          $0.allowedRange.lowerBound,
          $0.allowedRange.upperBound,
          $0.preference,
          $0.activeTier
        )
      }
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        self.observeRouter()
        self.publishAll()
      }
    }
  }

  private func publishAll() {
    snapshotHandler?(currentSnapshot)
    configurationHandler?(currentConfigurations)
  }

  private static func makeSnapshot(_ item: ExternalDisplayItem) -> MonitorSnapshot {
    MonitorSnapshot(
      id: MonitorID(rawValue: item.id),
      name: item.name,
      brightness: item.brightness,
      allowedRange: item.allowedRange,
      control: .available(item.tier.presentationMethod)
    )
  }

  private static func makeConfigurationSnapshot(
    _ item: DisplayConfigurationItem
  ) -> MonitorConfigurationSnapshot {
    MonitorConfigurationSnapshot(
      id: MonitorID(rawValue: item.id),
      name: item.name,
      isConnected: item.isConnected,
      brightness: item.brightness,
      allowedRange: item.allowedRange,
      preference: item.preference.presentationPreference,
      activeMethod: item.activeTier?.presentationMethod
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

private extension BrightnessControlPreference {
  var presentationPreference: MonitorControlPreference {
    switch self {
    case .automatic: .automatic
    case .hardware: .hardware
    case .software: .software
    case .shade: .shade
    }
  }
}

private extension MonitorControlPreference {
  var backendPreference: BrightnessControlPreference {
    switch self {
    case .automatic: .automatic
    case .hardware: .hardware
    case .software: .software
    case .shade: .shade
    }
  }
}
