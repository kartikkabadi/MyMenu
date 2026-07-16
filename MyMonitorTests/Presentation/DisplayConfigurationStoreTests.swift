import XCTest
@testable import MyMonitorPresentation

@MainActor
final class DisplayConfigurationStoreTests: XCTestCase {
  func testInitialSnapshotsPreserveConnectedAndRememberedDisplays() {
    let configurationController = FakeConfigurationController(
      configurations: [
        connectedConfiguration(),
        disconnectedConfiguration(),
      ]
    )
    let store = DisplayConfigurationStore(controller: configurationController)

    XCTAssertEqual(store.configurations.count, 2)
    XCTAssertTrue(store.configurations[0].isConnected)
    XCTAssertFalse(store.configurations[1].isConnected)
    XCTAssertEqual(store.configurations[1].preference, .shade)
  }

  func testMinimumCannotExceedCurrentMaximum() {
    let controller = FakeConfigurationController(
      configurations: [connectedConfiguration(range: 0.2...0.8)]
    )
    let store = DisplayConfigurationStore(controller: controller)

    store.setMinimumBrightness(0.95, for: monitorID)

    XCTAssertEqual(controller.rangeWrites.last?.range, 0.8...0.8)
    XCTAssertEqual(store.configuration(withID: monitorID)?.allowedRange, 0.8...0.8)
  }

  func testMaximumCannotFallBelowCurrentMinimum() {
    let controller = FakeConfigurationController(
      configurations: [connectedConfiguration(range: 0.3...0.9)]
    )
    let store = DisplayConfigurationStore(controller: controller)

    store.setMaximumBrightness(0.1, for: monitorID)

    XCTAssertEqual(controller.rangeWrites.last?.range, 0.3...0.3)
    XCTAssertEqual(store.configuration(withID: monitorID)?.allowedRange, 0.3...0.3)
  }

  func testTighteningRangeClampsVisibleBrightnessOptimistically() {
    let controller = FakeConfigurationController(
      configurations: [connectedConfiguration(brightness: 0.9, range: 0...1)]
    )
    let store = DisplayConfigurationStore(controller: controller)

    store.setMaximumBrightness(0.6, for: monitorID)

    assertBrightness(store.configuration(withID: monitorID)?.brightness, equals: 0.6)
    XCTAssertEqual(controller.rangeWrites.last?.range, 0...0.6)
  }

  func testControlPreferenceUpdatesImmediatelyAndEmitsIntent() {
    let controller = FakeConfigurationController(
      configurations: [connectedConfiguration()]
    )
    let store = DisplayConfigurationStore(controller: controller)

    store.setControlPreference(.software, for: monitorID)

    XCTAssertEqual(store.configuration(withID: monitorID)?.preference, .software)
    XCTAssertEqual(
      controller.preferenceWrites.last,
      PreferenceWrite(preference: .software, monitorID: monitorID)
    )
  }

  func testFallbackExplanationComparesRequestedAndActiveMethods() {
    let snapshot = MonitorConfigurationSnapshot(
      id: monitorID,
      name: "Dell U2723QE",
      isConnected: true,
      brightness: 0.5,
      allowedRange: 0...1,
      preference: .hardware,
      activeMethod: .software
    )

    let configuration = MonitorConfiguration(snapshot: snapshot)

    XCTAssertEqual(
      configuration.fallbackExplanation,
      "The requested method is unavailable through this connection. MyMonitor is using software control instead."
    )
  }

  func testAutomaticPreferenceDoesNotProduceFallbackWarning() {
    var snapshot = connectedConfiguration()
    snapshot.preference = .automatic
    snapshot.activeMethod = .shade

    XCTAssertNil(MonitorConfiguration(snapshot: snapshot).fallbackExplanation)
  }

  func testForgetIsScopedToSelectedDisplayAndPublishesItsIdentity() {
    let secondID = MonitorID(rawValue: 99)
    let controller = FakeConfigurationController(
      configurations: [
        connectedConfiguration(),
        MonitorConfigurationSnapshot(
          id: secondID,
          name: "Second Display",
          isConnected: false,
          brightness: 0.4,
          allowedRange: 0...1,
          preference: .automatic,
          activeMethod: nil
        ),
      ]
    )
    let store = DisplayConfigurationStore(controller: controller)
    var forgottenNotifications: [MonitorID] = []
    store.onConfigurationForgotten = { forgottenNotifications.append($0) }

    store.forgetConfiguration(for: secondID)

    XCTAssertEqual(controller.forgottenMonitorIDs, [secondID])
    XCTAssertEqual(forgottenNotifications, [secondID])
    XCTAssertEqual(store.configurations.count, 2)
  }

  func testResetPublishesEveryDisplayIdentity() {
    let rememberedID = MonitorID(rawValue: 77)
    let controller = FakeConfigurationController(
      configurations: [
        connectedConfiguration(),
        disconnectedConfiguration(),
      ]
    )
    let store = DisplayConfigurationStore(controller: controller)
    var forgottenNotifications: [MonitorID] = []
    store.onConfigurationForgotten = { forgottenNotifications.append($0) }

    store.resetAllConfigurations()

    XCTAssertEqual(Set(controller.forgottenMonitorIDs), Set([monitorID, rememberedID]))
    XCTAssertEqual(Set(forgottenNotifications), Set([monitorID, rememberedID]))
  }

  func testControllerSnapshotReplacesOptimisticConfiguration() {
    let controller = FakeConfigurationController(
      configurations: [connectedConfiguration()]
    )
    let store = DisplayConfigurationStore(controller: controller)

    store.setControlPreference(.hardware, for: monitorID)

    var acknowledged = connectedConfiguration()
    acknowledged.preference = .hardware
    acknowledged.activeMethod = .hardware
    controller.emit([acknowledged])

    XCTAssertEqual(store.configuration(withID: monitorID)?.preference, .hardware)
    XCTAssertEqual(store.configuration(withID: monitorID)?.activeMethod, .hardware)
  }

  private let monitorID = MonitorID(rawValue: 42)

  private func connectedConfiguration(
    brightness: Double = 0.7,
    range: ClosedRange<Double> = 0.1...1
  ) -> MonitorConfigurationSnapshot {
    MonitorConfigurationSnapshot(
      id: monitorID,
      name: "Dell U2723QE",
      isConnected: true,
      brightness: brightness,
      allowedRange: range,
      preference: .automatic,
      activeMethod: .hardware
    )
  }

  private func disconnectedConfiguration() -> MonitorConfigurationSnapshot {
    MonitorConfigurationSnapshot(
      id: MonitorID(rawValue: 77),
      name: "Remembered Projector",
      isConnected: false,
      brightness: 0.4,
      allowedRange: 0.2...0.8,
      preference: .shade,
      activeMethod: nil
    )
  }
}

@MainActor
private final class FakeConfigurationController: DisplayConfigurationControlling {
  private(set) var currentConfigurations: [MonitorConfigurationSnapshot]
  private var handler: (@MainActor ([MonitorConfigurationSnapshot]) -> Void)?

  private(set) var rangeWrites: [RangeWrite] = []
  private(set) var preferenceWrites: [PreferenceWrite] = []
  private(set) var forgottenMonitorIDs: [MonitorID] = []

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
  ) {
    rangeWrites.append(RangeWrite(range: range, monitorID: monitorID))
  }

  func setControlPreference(
    _ preference: MonitorControlPreference,
    for monitorID: MonitorID
  ) {
    preferenceWrites.append(
      PreferenceWrite(preference: preference, monitorID: monitorID)
    )
  }

  func forgetConfiguration(for monitorID: MonitorID) {
    forgottenMonitorIDs.append(monitorID)
  }

  func emit(_ configurations: [MonitorConfigurationSnapshot]) {
    currentConfigurations = configurations
    handler?(configurations)
  }
}

private struct RangeWrite: Equatable {
  let range: ClosedRange<Double>
  let monitorID: MonitorID
}

private struct PreferenceWrite: Equatable {
  let preference: MonitorControlPreference
  let monitorID: MonitorID
}

private func assertBrightness(
  _ actual: Double?,
  equals expected: Double,
  accuracy: Double = 0.0001,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  guard let actual else {
    XCTFail("Expected a brightness value", file: file, line: line)
    return
  }
  XCTAssertEqual(actual, expected, accuracy: accuracy, file: file, line: line)
}
