import Foundation
import Observation

enum LaunchAtLoginServiceStatus: Equatable, Sendable {
  case notRegistered
  case enabled
  case requiresApproval
  case unavailable
}

@MainActor
protocol LaunchAtLoginServicing: AnyObject {
  var status: LaunchAtLoginServiceStatus { get }
  func register() throws
  func unregister() throws
}

/// Keeps the Settings toggle synchronized with the actual system login-item state.
@MainActor
@Observable
final class LaunchAtLoginController {
  private(set) var status: LaunchAtLoginServiceStatus
  private(set) var errorMessage: String?

  @ObservationIgnored
  private let service: any LaunchAtLoginServicing

  init(service: any LaunchAtLoginServicing) {
    self.service = service
    status = service.status
  }

  var isRequested: Bool {
    status == .enabled || status == .requiresApproval
  }

  var canChange: Bool {
    status != .unavailable
  }

  func setRequested(_ requested: Bool) {
    errorMessage = nil

    do {
      if requested {
        try service.register()
      } else {
        try service.unregister()
      }
    } catch {
      errorMessage = error.localizedDescription
    }

    refresh()
  }

  func refresh() {
    status = service.status
  }
}
