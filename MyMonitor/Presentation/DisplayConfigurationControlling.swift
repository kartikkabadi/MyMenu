import Foundation

/// Narrow configuration boundary between Settings and display infrastructure.
@MainActor
protocol DisplayConfigurationControlling: AnyObject {
  var currentConfigurations: [MonitorConfigurationSnapshot] { get }

  func setConfigurationHandler(
    _ handler: @escaping @MainActor ([MonitorConfigurationSnapshot]) -> Void
  )

  func setBrightnessRange(
    _ range: ClosedRange<Double>,
    for monitorID: MonitorID
  )

  func setControlPreference(
    _ preference: MonitorControlPreference,
    for monitorID: MonitorID
  )

  func forgetConfiguration(for monitorID: MonitorID)
}
