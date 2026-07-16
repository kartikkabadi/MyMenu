import Foundation

@MainActor
final class SystemKeyboardShortcutPreferences: KeyboardShortcutPersisting {
  private static let configurationKey = "MyMonitor.v1.keyboardShortcutConfiguration"

  private let defaults: UserDefaults
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func loadConfiguration() -> KeyboardShortcutConfiguration {
    guard let data = defaults.data(forKey: Self.configurationKey),
      let configuration = try? decoder.decode(
        KeyboardShortcutConfiguration.self,
        from: data
      )
    else {
      return .empty
    }
    return configuration
  }

  func saveConfiguration(_ configuration: KeyboardShortcutConfiguration) {
    guard let data = try? encoder.encode(configuration) else { return }
    defaults.set(data, forKey: Self.configurationKey)
  }
}
