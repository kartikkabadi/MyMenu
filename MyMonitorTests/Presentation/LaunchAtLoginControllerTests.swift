import XCTest
@testable import MyMonitorPresentation

@MainActor
final class LaunchAtLoginControllerTests: XCTestCase {
  func testInitialStateReflectsTheSystemService() {
    let service = FakeLaunchAtLoginService(status: .enabled)
    let controller = LaunchAtLoginController(service: service)

    XCTAssertEqual(controller.status, .enabled)
    XCTAssertTrue(controller.isRequested)
    XCTAssertTrue(controller.canChange)
    XCTAssertNil(controller.errorMessage)
  }

  func testEnableRegistersAndRefreshesToTheActualSystemState() {
    let service = FakeLaunchAtLoginService(status: .notRegistered)
    service.statusAfterRegister = .enabled
    let controller = LaunchAtLoginController(service: service)

    controller.setRequested(true)

    XCTAssertEqual(service.registerCount, 1)
    XCTAssertEqual(service.unregisterCount, 0)
    XCTAssertEqual(controller.status, .enabled)
    XCTAssertTrue(controller.isRequested)
    XCTAssertNil(controller.errorMessage)
  }

  func testDisableUnregistersARequestThatStillRequiresApproval() {
    let service = FakeLaunchAtLoginService(status: .requiresApproval)
    service.statusAfterUnregister = .notRegistered
    let controller = LaunchAtLoginController(service: service)

    XCTAssertTrue(controller.isRequested)

    controller.setRequested(false)

    XCTAssertEqual(service.unregisterCount, 1)
    XCTAssertEqual(service.registerCount, 0)
    XCTAssertEqual(controller.status, .notRegistered)
    XCTAssertFalse(controller.isRequested)
    XCTAssertNil(controller.errorMessage)
  }

  func testRegistrationFailureIsVisibleAndDoesNotChangeTheReportedState() {
    let service = FakeLaunchAtLoginService(status: .notRegistered)
    service.registerError = TestServiceError.registrationFailed
    let controller = LaunchAtLoginController(service: service)

    controller.setRequested(true)

    XCTAssertEqual(service.registerCount, 1)
    XCTAssertEqual(controller.status, .notRegistered)
    XCTAssertFalse(controller.isRequested)
    XCTAssertEqual(controller.errorMessage, "Registration failed")
  }

  func testARequiresApprovalStateRemainsRequestedButExplainsTheSystemGate() {
    let service = FakeLaunchAtLoginService(status: .notRegistered)
    service.statusAfterRegister = .requiresApproval
    let controller = LaunchAtLoginController(service: service)

    controller.setRequested(true)

    XCTAssertEqual(controller.status, .requiresApproval)
    XCTAssertTrue(controller.isRequested)
    XCTAssertTrue(controller.canChange)
  }

  func testUnavailableServiceDisablesTheSetting() {
    let service = FakeLaunchAtLoginService(status: .unavailable)
    let controller = LaunchAtLoginController(service: service)

    XCTAssertEqual(controller.status, .unavailable)
    XCTAssertFalse(controller.isRequested)
    XCTAssertFalse(controller.canChange)
  }

  func testRefreshReadsExternalSystemChanges() {
    let service = FakeLaunchAtLoginService(status: .notRegistered)
    let controller = LaunchAtLoginController(service: service)

    service.status = .enabled
    controller.refresh()

    XCTAssertEqual(controller.status, .enabled)
    XCTAssertTrue(controller.isRequested)
  }
}

@MainActor
private final class FakeLaunchAtLoginService: LaunchAtLoginServicing {
  var status: LaunchAtLoginServiceStatus
  var statusAfterRegister: LaunchAtLoginServiceStatus?
  var statusAfterUnregister: LaunchAtLoginServiceStatus?
  var registerError: Error?
  var unregisterError: Error?

  private(set) var registerCount = 0
  private(set) var unregisterCount = 0

  init(status: LaunchAtLoginServiceStatus) {
    self.status = status
  }

  func register() throws {
    registerCount += 1
    if let registerError {
      throw registerError
    }
    if let statusAfterRegister {
      status = statusAfterRegister
    }
  }

  func unregister() throws {
    unregisterCount += 1
    if let unregisterError {
      throw unregisterError
    }
    if let statusAfterUnregister {
      status = statusAfterUnregister
    }
  }
}

private enum TestServiceError: LocalizedError {
  case registrationFailed

  var errorDescription: String? {
    switch self {
    case .registrationFailed:
      "Registration failed"
    }
  }
}
