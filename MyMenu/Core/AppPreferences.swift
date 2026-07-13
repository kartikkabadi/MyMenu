import Foundation

struct AppPreferences {
  static let isWindowSnappingEnabledKey = "MyMenu.isWindowSnappingEnabled"
  static let isWindowSwitcherEnabledKey = "MyMenu.isWindowSwitcherEnabled"

  static var isWindowSnappingEnabled: Bool {
    get {
      UserDefaults.standard.object(forKey: isWindowSnappingEnabledKey) as? Bool ?? true
    }
    set {
      UserDefaults.standard.set(newValue, forKey: isWindowSnappingEnabledKey)
    }
  }

  static var isWindowSwitcherEnabled: Bool {
    get {
      UserDefaults.standard.object(forKey: isWindowSwitcherEnabledKey) as? Bool ?? true
    }
    set {
      UserDefaults.standard.set(newValue, forKey: isWindowSwitcherEnabledKey)
    }
  }
}
