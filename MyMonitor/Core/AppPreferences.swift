import Foundation

struct AppPreferences {
  static let hasCompletedOnboardingKey = "MyMonitor.hasCompletedOnboarding"
  static let isWindowSnappingEnabledKey = "MyMonitor.isWindowSnappingEnabled"
  static let isWindowSwitcherEnabledKey = "MyMonitor.isWindowSwitcherEnabled"

  static var hasCompletedOnboarding: Bool {
    get {
      UserDefaults.standard.object(forKey: hasCompletedOnboardingKey) as? Bool ?? false
    }
    set {
      UserDefaults.standard.set(newValue, forKey: hasCompletedOnboardingKey)
    }
  }

  static var isWindowSnappingEnabled: Bool {
    get {
      UserDefaults.standard.object(forKey: isWindowSnappingEnabledKey) as? Bool ?? false
    }
    set {
      UserDefaults.standard.set(newValue, forKey: isWindowSnappingEnabledKey)
    }
  }

  static var isWindowSwitcherEnabled: Bool {
    get {
      UserDefaults.standard.object(forKey: isWindowSwitcherEnabledKey) as? Bool ?? false
    }
    set {
      UserDefaults.standard.set(newValue, forKey: isWindowSwitcherEnabledKey)
    }
  }
}
