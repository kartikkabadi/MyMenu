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
    case .general: "General"
    case .displays: "Displays"
    case .keyboard: "Keyboard"
    case .advanced: "Advanced"
    case .about: "About"
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
