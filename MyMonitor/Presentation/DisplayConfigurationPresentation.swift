import Foundation

/// User-facing per-display control strategy.
enum MonitorControlPreference: String, CaseIterable, Identifiable, Equatable, Sendable {
  case automatic
  case hardware
  case software
  case shade

  var id: Self { self }

  var label: String {
    switch self {
    case .automatic: "Automatic"
    case .hardware: "Hardware control"
    case .software: "Software control"
    case .shade: "Display shade"
    }
  }

  var expectedMethod: MonitorControlMethod? {
    switch self {
    case .automatic: nil
    case .hardware: .hardware
    case .software: .software
    case .shade: .shade
    }
  }
}

/// Controller snapshot before frontend reconciliation.
struct MonitorConfigurationSnapshot: Identifiable, Equatable, Sendable {
  let id: MonitorID
  var name: String
  var isConnected: Bool
  var brightness: Double?
  var allowedRange: ClosedRange<Double>
  var preference: MonitorControlPreference
  var activeMethod: MonitorControlMethod?
}

/// Presentation-ready configuration consumed by Settings.
struct MonitorConfiguration: Identifiable, Equatable, Sendable {
  let id: MonitorID
  var name: String
  var isConnected: Bool
  var brightness: Double?
  var allowedRange: ClosedRange<Double>
  var preference: MonitorControlPreference
  var activeMethod: MonitorControlMethod?

  init(snapshot: MonitorConfigurationSnapshot) {
    id = snapshot.id
    name = snapshot.name
    isConnected = snapshot.isConnected
    brightness = snapshot.brightness.map { min(max($0, 0), 1) }

    let lower = min(max(snapshot.allowedRange.lowerBound, 0), 1)
    let upper = min(max(snapshot.allowedRange.upperBound, 0), 1)
    allowedRange = min(lower, upper)...max(lower, upper)
    preference = snapshot.preference
    activeMethod = snapshot.activeMethod
  }

  var fallbackExplanation: String? {
    guard isConnected,
      let expected = preference.expectedMethod,
      let activeMethod,
      expected != activeMethod
    else {
      return nil
    }

    return "The requested method is unavailable through this connection. MyMonitor is using \(activeMethod.label.lowercased()) instead."
  }
}
