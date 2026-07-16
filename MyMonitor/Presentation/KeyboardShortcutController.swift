import Foundation
import Observation

struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
  let rawValue: UInt32

  static let control = Self(rawValue: 1 << 0)
  static let option = Self(rawValue: 1 << 1)
  static let shift = Self(rawValue: 1 << 2)
  static let command = Self(rawValue: 1 << 3)
}

struct RecordedShortcut: Codable, Equatable, Hashable, Sendable {
  var keyCode: UInt32
  var modifiers: ShortcutModifiers
  var keyDisplay: String

  var displayText: String {
    var result = ""
    if modifiers.contains(.control) { result += "⌃" }
    if modifiers.contains(.option) { result += "⌥" }
    if modifiers.contains(.shift) { result += "⇧" }
    if modifiers.contains(.command) { result += "⌘" }
    return result + keyDisplay
  }

  var isValid: Bool {
    !modifiers.isEmpty && !keyDisplay.isEmpty
  }
}

enum KeyboardShortcutAction: UInt32, Codable, CaseIterable, Equatable, Hashable, Sendable {
  case decreaseBrightness = 1
  case increaseBrightness = 2

  var title: String {
    switch self {
    case .decreaseBrightness: String(localized: "Decrease brightness")
    case .increaseBrightness: String(localized: "Increase brightness")
    }
  }

  var delta: Double {
    switch self {
    case .decreaseBrightness: -0.05
    case .increaseBrightness: 0.05
    }
  }
}

enum KeyboardBrightnessTarget: Codable, Equatable, Hashable, Sendable {
  case displayUnderPointer
  case allExternalDisplays
  case display(MonitorID)
}

struct KeyboardShortcutConfiguration: Codable, Equatable, Sendable {
  var decreaseShortcut: RecordedShortcut?
  var increaseShortcut: RecordedShortcut?
  var target: KeyboardBrightnessTarget

  static let empty = Self(
    decreaseShortcut: nil,
    increaseShortcut: nil,
    target: .displayUnderPointer
  )

  var registrations: [GlobalHotKeyRegistration] {
    var result: [GlobalHotKeyRegistration] = []
    if let decreaseShortcut {
      result.append(
        GlobalHotKeyRegistration(
          action: .decreaseBrightness,
          shortcut: decreaseShortcut
        )
      )
    }
    if let increaseShortcut {
      result.append(
        GlobalHotKeyRegistration(
          action: .increaseBrightness,
          shortcut: increaseShortcut
        )
      )
    }
    return result
  }
}

struct GlobalHotKeyRegistration: Equatable, Sendable {
  var action: KeyboardShortcutAction
  var shortcut: RecordedShortcut
}

@MainActor
protocol GlobalHotKeyServing: AnyObject {
  func replaceRegistrations(
    _ registrations: [GlobalHotKeyRegistration],
    handler: @escaping @MainActor (KeyboardShortcutAction) -> Void
  ) throws

  func unregisterAll()
}

@MainActor
protocol KeyboardShortcutPersisting: AnyObject {
  func loadConfiguration() -> KeyboardShortcutConfiguration
  func saveConfiguration(_ configuration: KeyboardShortcutConfiguration)
}

@MainActor
@Observable
final class KeyboardShortcutController {
  private(set) var configuration: KeyboardShortcutConfiguration
  private(set) var errorMessage: String?
  var actionHandler: (@MainActor (KeyboardShortcutAction, KeyboardBrightnessTarget) -> Void)?

  @ObservationIgnored
  private let service: any GlobalHotKeyServing

  @ObservationIgnored
  private let persistence: any KeyboardShortcutPersisting

  init(
    service: any GlobalHotKeyServing,
    persistence: any KeyboardShortcutPersisting
  ) {
    self.service = service
    self.persistence = persistence
    configuration = persistence.loadConfiguration()
    install(configuration)
  }

  func shortcut(for action: KeyboardShortcutAction) -> RecordedShortcut? {
    switch action {
    case .decreaseBrightness: configuration.decreaseShortcut
    case .increaseBrightness: configuration.increaseShortcut
    }
  }

  func setShortcut(
    _ shortcut: RecordedShortcut?,
    for action: KeyboardShortcutAction
  ) {
    var candidate = configuration
    switch action {
    case .decreaseBrightness:
      candidate.decreaseShortcut = shortcut
    case .increaseBrightness:
      candidate.increaseShortcut = shortcut
    }

    if let shortcut, !shortcut.isValid {
      errorMessage = String(
        localized: "Shortcuts must include at least one modifier key."
      )
      return
    }

    if let decrease = candidate.decreaseShortcut,
      let increase = candidate.increaseShortcut,
      decrease == increase
    {
      errorMessage = String(
        localized: "Increase and decrease brightness cannot use the same shortcut."
      )
      return
    }

    guard register(candidate) else { return }
    configuration = candidate
    persistence.saveConfiguration(candidate)
  }

  func setTarget(_ target: KeyboardBrightnessTarget) {
    configuration.target = target
    persistence.saveConfiguration(configuration)
    errorMessage = nil
  }

  func clearError() {
    errorMessage = nil
  }

  func teardown() {
    service.unregisterAll()
  }

  private func install(_ configuration: KeyboardShortcutConfiguration) {
    if !register(configuration) {
      service.unregisterAll()
    }
  }

  private func register(_ candidate: KeyboardShortcutConfiguration) -> Bool {
    do {
      try service.replaceRegistrations(candidate.registrations) { [weak self] action in
        guard let self else { return }
        self.actionHandler?(action, self.configuration.target)
      }
      errorMessage = nil
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }
}
