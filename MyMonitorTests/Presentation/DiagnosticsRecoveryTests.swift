import XCTest
@testable import MyMonitorPresentation

final class DiagnosticReportTests: XCTestCase {
  func testReportContainsOnlyApprovedSupportContext() {
    let monitorID = MonitorID(rawValue: 42)
    let report = DiagnosticReport.render(
      DiagnosticReportContext(
        appVersion: "0.1.0",
        appBuild: "17",
        operatingSystem: "macOS 26.5.1",
        architecture: "arm64",
        configurations: [
          MonitorConfiguration(
            snapshot: MonitorConfigurationSnapshot(
              id: monitorID,
              name: "Dell U2723QE",
              isConnected: true,
              brightness: 0.72,
              allowedRange: 0.1...0.9,
              preference: .hardware,
              activeMethod: .software
            )
          ),
        ],
        currentError: "Hardware control unavailable",
        focusedMonitorID: monitorID
      )
    )

    XCTAssertTrue(report.contains("Version: 0.1.0"))
    XCTAssertTrue(report.contains("Build: 17"))
    XCTAssertTrue(report.contains("macOS: macOS 26.5.1"))
    XCTAssertTrue(report.contains("Architecture: arm64"))
    XCTAssertTrue(report.contains("Dell U2723QE [focused]"))
    XCTAssertTrue(report.contains("Support ID: 42"))
    XCTAssertTrue(report.contains("Brightness: 72%"))
    XCTAssertTrue(report.contains("Allowed range: 10%–90%"))
    XCTAssertTrue(report.contains("Requested method: Hardware control"))
    XCTAssertTrue(report.contains("Active method: Software control"))
    XCTAssertTrue(report.contains("Hardware control unavailable"))
    XCTAssertTrue(report.contains("does not include window titles"))
    XCTAssertFalse(report.contains("/Users/"))
  }

  func testReportSanitizesInjectedLineBreaks() {
    let report = DiagnosticReport.render(
      DiagnosticReportContext(
        appVersion: "1.0\nInjected",
        appBuild: "1\rInjected",
        operatingSystem: "macOS\nInjected",
        architecture: "arm64",
        configurations: [],
        currentError: "Failure\nInjected",
        focusedMonitorID: nil
      )
    )

    XCTAssertTrue(report.contains("Version: 1.0 Injected"))
    XCTAssertTrue(report.contains("Build: 1 Injected"))
    XCTAssertTrue(report.contains("macOS: macOS Injected"))
    XCTAssertTrue(report.contains("Failure Injected"))
  }

  func testEmptyReportDoesNotInventDisplayData() {
    let report = DiagnosticReport.render(
      DiagnosticReportContext(
        appVersion: "Development",
        appBuild: "Development",
        operatingSystem: "macOS",
        architecture: "arm64",
        configurations: [],
        currentError: nil,
        focusedMonitorID: nil
      )
    )

    XCTAssertTrue(report.contains("No connected or remembered external displays."))
    XCTAssertFalse(report.contains("Support ID:"))
    XCTAssertFalse(report.contains("Current Error"))
  }
}

@MainActor
final class DiagnosticsRecoveryStoreTests: XCTestCase {
  func testRetryAllMarksEveryVisibleMonitorCheckingAndUsesControllerRetry() {
    let controller = RecoveryMonitorController(
      snapshot: MonitorPresentationFixtures.twoMixedDisplays
    )
    let store = DisplayPresentationStore(controller: controller)

    store.retryAllControls()

    XCTAssertEqual(store.monitors.map(\.control), [.checking, .checking])
    XCTAssertEqual(controller.retryAllCount, 1)
  }

  func testResetAllUsesScopedForgetForConnectedAndRememberedDisplays() {
    let connectedID = MonitorID(rawValue: 1)
    let rememberedID = MonitorID(rawValue: 2)
    let controller = RecoveryConfigurationController(
      configurations: [
        MonitorConfigurationSnapshot(
          id: connectedID,
          name: "Connected Display",
          isConnected: true,
          brightness: 0.5,
          allowedRange: 0.2...0.8,
          preference: .hardware,
          activeMethod: .hardware
        ),
        MonitorConfigurationSnapshot(
          id: rememberedID,
          name: "Remembered Display",
          isConnected: false,
          brightness: 0.4,
          allowedRange: 0.1...0.7,
          preference: .shade,
          activeMethod: nil
        ),
      ]
    )
    let store = DisplayConfigurationStore(controller: controller)

    store.resetAllConfigurations()

    XCTAssertEqual(controller.forgottenIDs, [connectedID, rememberedID])
  }
}

@MainActor
private final class RecoveryMonitorController: MonitorControlling {
  private(set) var currentSnapshot: DisplayControllerSnapshot
  private var handler: (@MainActor (DisplayControllerSnapshot) -> Void)?
  private(set) var retryAllCount = 0

  init(snapshot: DisplayControllerSnapshot) {
    currentSnapshot = snapshot
  }

  func setSnapshotHandler(
    _ handler: @escaping @MainActor (DisplayControllerSnapshot) -> Void
  ) {
    self.handler = handler
  }

  func refresh() {}

  func setBrightness(
    _ value: Double,
    for monitorID: MonitorID,
    animated: Bool,
    persist: Bool
  ) {}

  func retryControl(for monitorID: MonitorID) {}

  func retryAllControls() {
    retryAllCount += 1
  }

  func teardown() {}
}

@MainActor
private final class RecoveryConfigurationController: DisplayConfigurationControlling {
  private(set) var currentConfigurations: [MonitorConfigurationSnapshot]
  private var handler: (@MainActor ([MonitorConfigurationSnapshot]) -> Void)?
  private(set) var forgottenIDs: [MonitorID] = []

  init(configurations: [MonitorConfigurationSnapshot]) {
    currentConfigurations = configurations
  }

  func setConfigurationHandler(
    _ handler: @escaping @MainActor ([MonitorConfigurationSnapshot]) -> Void
  ) {
    self.handler = handler
  }

  func setBrightnessRange(
    _ range: ClosedRange<Double>,
    for monitorID: MonitorID
  ) {}

  func setControlPreference(
    _ preference: MonitorControlPreference,
    for monitorID: MonitorID
  ) {}

  func forgetConfiguration(for monitorID: MonitorID) {
    forgottenIDs.append(monitorID)
  }
}
