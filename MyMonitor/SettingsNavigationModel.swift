import Foundation
import Observation

@MainActor
@Observable
final class SettingsNavigationModel {
  var selection: SettingsDestination = .general
}

enum SettingsDestination: String, CaseIterable, Identifiable {
  case general
  case displays
  case keyboard
  case advanced
  case about

  var id: Self { self }

  var title: String {
    switch self {
    case .general: String(localized: "General")
    case .displays: String(localized: "Displays")
    case .keyboard: String(localized: "Keyboard")
    case .advanced: String(localized: "Advanced")
    case .about: String(localized: "About")
    }
  }

  var symbol: String {
    switch self {
    case .general: "gearshape"
    case .displays: "display.2"
    case .keyboard: "keyboard"
    case .advanced: "wrench.and.screwdriver"
    case .about: "info.circle"
    }
  }
}
