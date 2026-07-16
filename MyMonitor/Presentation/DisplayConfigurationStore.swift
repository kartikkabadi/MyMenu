import Foundation
import Observation

/// Hardware-independent Settings state for remembered and connected displays.
@MainActor
@Observable
final class DisplayConfigurationStore {
  private(set) var configurations: [MonitorConfiguration]

  @ObservationIgnored
  private let controller: any DisplayConfigurationControlling

  init(controller: any DisplayConfigurationControlling) {
    self.controller = controller
    configurations = controller.currentConfigurations.map(MonitorConfiguration.init)

    controller.setConfigurationHandler { [weak self] snapshots in
      self?.configurations = snapshots.map(MonitorConfiguration.init)
    }
  }

  func configuration(withID monitorID: MonitorID) -> MonitorConfiguration? {
    configurations.first { $0.id == monitorID }
  }

  func setMinimumBrightness(_ value: Double, for monitorID: MonitorID) {
    guard let configuration = configuration(withID: monitorID) else { return }
    let minimum = min(max(value, 0), configuration.allowedRange.upperBound)
    setRange(minimum...configuration.allowedRange.upperBound, for: monitorID)
  }

  func setMaximumBrightness(_ value: Double, for monitorID: MonitorID) {
    guard let configuration = configuration(withID: monitorID) else { return }
    let maximum = max(min(value, 1), configuration.allowedRange.lowerBound)
    setRange(configuration.allowedRange.lowerBound...maximum, for: monitorID)
  }

  func setControlPreference(
    _ preference: MonitorControlPreference,
    for monitorID: MonitorID
  ) {
    updateConfiguration(withID: monitorID) { configuration in
      configuration.preference = preference
    }
    controller.setControlPreference(preference, for: monitorID)
  }

  func forgetConfiguration(for monitorID: MonitorID) {
    controller.forgetConfiguration(for: monitorID)
  }

  private func setRange(
    _ range: ClosedRange<Double>,
    for monitorID: MonitorID
  ) {
    updateConfiguration(withID: monitorID) { configuration in
      configuration.allowedRange = range
      if let brightness = configuration.brightness {
        configuration.brightness = min(
          max(brightness, range.lowerBound),
          range.upperBound
        )
      }
    }
    controller.setBrightnessRange(range, for: monitorID)
  }

  private func updateConfiguration(
    withID monitorID: MonitorID,
    _ update: (inout MonitorConfiguration) -> Void
  ) {
    guard let index = configurations.firstIndex(where: { $0.id == monitorID }) else { return }
    update(&configurations[index])
  }
}
