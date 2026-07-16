import Foundation

/// Stable frontend identity for one externally controlled display.
///
/// The presentation layer deliberately does not expose Core Graphics display types.
struct MonitorID: Hashable, RawRepresentable, Codable, Sendable {
  let rawValue: UInt32

  init(rawValue: UInt32) {
    self.rawValue = rawValue
  }
}

/// User-facing control methods. Backend implementation names stay behind the adapter.
enum MonitorControlMethod: String, Equatable, Sendable {
  case hardware
  case software
  case shade

  var label: String {
    switch self {
    case .hardware: String(localized: "Hardware control")
    case .software: String(localized: "Software control")
    case .shade: String(localized: "Display shade")
    }
  }
}

/// Capability state for one monitor row.
enum MonitorControlState: Equatable, Sendable {
  case checking
  case available(MonitorControlMethod)
  case unavailable(message: String, canRetry: Bool)

  var label: String {
    switch self {
    case .checking:
      String(localized: "Checking hardware control…")
    case .available(let method):
      method.label
    case .unavailable:
      String(localized: "Brightness unavailable")
    }
  }
}

/// Snapshot supplied by a monitor controller before frontend-specific reconciliation.
struct MonitorSnapshot: Identifiable, Equatable, Sendable {
  let id: MonitorID
  var name: String
  var brightness: Double?
  var allowedRange: ClosedRange<Double>
  var control: MonitorControlState

  init(
    id: MonitorID,
    name: String,
    brightness: Double?,
    allowedRange: ClosedRange<Double> = 0...1,
    control: MonitorControlState
  ) {
    self.id = id
    self.name = name
    self.brightness = brightness
    self.allowedRange = allowedRange
    self.control = control
  }
}

/// Presentation-ready row consumed by SwiftUI.
struct MonitorPresentation: Identifiable, Equatable, Sendable {
  let id: MonitorID
  var name: String
  var brightness: Double?
  var allowedRange: ClosedRange<Double>
  var control: MonitorControlState

  init(snapshot: MonitorSnapshot, brightnessOverride: Double? = nil) {
    id = snapshot.id
    name = snapshot.name
    allowedRange = snapshot.allowedRange
    control = snapshot.control

    if let brightnessOverride {
      brightness = min(max(brightnessOverride, allowedRange.lowerBound), allowedRange.upperBound)
    } else if let snapshotBrightness = snapshot.brightness {
      brightness = min(max(snapshotBrightness, allowedRange.lowerBound), allowedRange.upperBound)
    } else {
      brightness = nil
    }
  }
}

struct DisplayPresentationFailure: Equatable, Sendable {
  var message: String
  var canRetry: Bool
}

/// Explicit top-level state for the menu-bar and Settings surfaces.
enum DisplayPresentationState: Equatable, Sendable {
  case detecting(cached: [MonitorPresentation])
  case ready([MonitorPresentation])
  case empty
  case failed(DisplayPresentationFailure)

  var monitors: [MonitorPresentation] {
    switch self {
    case .detecting(let cached), .ready(let cached):
      cached
    case .empty, .failed:
      []
    }
  }

  var isDetecting: Bool {
    if case .detecting = self { return true }
    return false
  }
}

/// State emitted by the backend-facing controller.
enum DisplayControllerSnapshot: Equatable, Sendable {
  case detecting(cached: [MonitorSnapshot])
  case ready([MonitorSnapshot])
  case failed(message: String, canRetry: Bool)
}
