import ServiceManagement

/// System adapter for registering the main app as a macOS login item.
@MainActor
final class SystemLaunchAtLoginService: LaunchAtLoginServicing {
  private let service = SMAppService.mainApp

  var status: LaunchAtLoginServiceStatus {
    switch service.status {
    case .notRegistered:
      .notRegistered
    case .enabled:
      .enabled
    case .requiresApproval:
      .requiresApproval
    case .notFound:
      .unavailable
    @unknown default:
      .unavailable
    }
  }

  func register() throws {
    try service.register()
  }

  func unregister() throws {
    try service.unregister()
  }
}
