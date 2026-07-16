import XCTest
@testable import MyMonitorPresentation

@MainActor
final class DisplayPresentationStoreTests: XCTestCase {
  func testEmptyControllerSnapshotMapsToEmptyPresentation() {
    let controller = FakeMonitorController(snapshot: .ready([]))
    let store = DisplayPresentationStore(controller: controller)

    XCTAssertEqual(store.state, .empty)
    XCTAssertTrue(store.monitors.isEmpty)
  }

  func testReadySnapshotPreservesControllerOrderAndControlState() {
    let controller = FakeMonitorController(
      snapshot: MonitorPresentationFixtures.twoMixedDisplays
    )
    let store = DisplayPresentationStore(controller: controller)

    XCTAssertEqual(
      store.monitors.map(\.id),
      [
        MonitorPresentationFixtures.studioDisplayID,
        MonitorPresentationFixtures.projectorID,
      ]
    )
    XCTAssertEqual(store.monitors[0].control, .available(.hardware))
    XCTAssertEqual(store.monitors[1].control, .available(.shade))
  }

  func testBrightnessUpdateClampsToAllowedRangeAndDoesNotPersistWhileDragging() {
    let monitorID = MonitorID(rawValue: 42)
    let snapshot = MonitorSnapshot(
      id: monitorID,
      name: "Bounded Display",
      brightness: 0.5,
      allowedRange: 0.2...0.9,
      control: .available(.hardware)
    )
    let controller = FakeMonitorController(snapshot: .ready([snapshot]))
    let store = DisplayPresentationStore(controller: controller)

    store.beginBrightnessAdjustment(for: monitorID)
    store.updateBrightness(1.2, for: monitorID)

    XCTAssertEqual(store.monitor(withID: monitorID)?.brightness, 0.9, accuracy: 0.0001)
    XCTAssertEqual(
      controller.writes.last,
      .init(
        value: 0.9,
        monitorID: monitorID,
        animated: false,
        persist: false
      )
    )
  }

  func testStaleSnapshotCannotMoveActiveSliderAwayFromUserValue() {
    let monitorID = MonitorPresentationFixtures.studioDisplayID
    let controller = FakeMonitorController(
      snapshot: MonitorPresentationFixtures.oneHardwareDisplay
    )
    let store = DisplayPresentationStore(controller: controller)

    store.beginBrightnessAdjustment(for: monitorID)
    store.updateBrightness(0.81, for: monitorID)

    var stale = MonitorPresentationFixtures.hardwareSnapshot
    stale.brightness = 0.42
    controller.emit(.ready([stale]))

    XCTAssertEqual(store.monitor(withID: monitorID)?.brightness, 0.81, accuracy: 0.0001)
  }

  func testAcknowledgedFinalWriteReleasesOptimisticOverride() {
    let monitorID = MonitorPresentationFixtures.studioDisplayID
    let controller = FakeMonitorController(
      snapshot: MonitorPresentationFixtures.oneHardwareDisplay
    )
    let store = DisplayPresentationStore(controller: controller)

    store.beginBrightnessAdjustment(for: monitorID)
    store.updateBrightness(0.81, for: monitorID)
    store.endBrightnessAdjustment(for: monitorID)

    XCTAssertEqual(
      controller.writes.last,
      .init(
        value: 0.81,
        monitorID: monitorID,
        animated: true,
        persist: true
      )
    )

    var acknowledgement = MonitorPresentationFixtures.hardwareSnapshot
    acknowledgement.brightness = 0.81
    controller.emit(.ready([acknowledgement]))

    var laterHardwareChange = acknowledgement
    laterHardwareChange.brightness = 0.67
    controller.emit(.ready([laterHardwareChange]))

    XCTAssertEqual(store.monitor(withID: monitorID)?.brightness, 0.67, accuracy: 0.0001)
  }

  func testRefreshPublishesDetectingStateWithCurrentRows() {
    let controller = FakeMonitorController(
      snapshot: MonitorPresentationFixtures.twoMixedDisplays
    )
    let store = DisplayPresentationStore(controller: controller)

    store.refresh()

    XCTAssertTrue(store.state.isDetecting)
    XCTAssertEqual(store.monitors.count, 2)
    XCTAssertEqual(controller.refreshCount, 1)
  }

  func testRemovingMonitorClearsItsOptimisticValue() {
    let monitorID = MonitorPresentationFixtures.studioDisplayID
    let controller = FakeMonitorController(
      snapshot: MonitorPresentationFixtures.oneHardwareDisplay
    )
    let store = DisplayPresentationStore(controller: controller)

    store.beginBrightnessAdjustment(for: monitorID)
    store.updateBrightness(0.91, for: monitorID)
    controller.emit(.ready([]))
    XCTAssertEqual(store.state, .empty)

    var reconnected = MonitorPresentationFixtures.hardwareSnapshot
    reconnected.brightness = 0.34
    controller.emit(.ready([reconnected]))

    XCTAssertEqual(store.monitor(withID: monitorID)?.brightness, 0.34, accuracy: 0.0001)
  }

  func testFixturesCoverRequiredPresentationStatesDeterministically() {
    let snapshots: [DisplayControllerSnapshot] = [
      MonitorPresentationFixtures.empty,
      MonitorPresentationFixtures.detecting,
      MonitorPresentationFixtures.oneHardwareDisplay,
      MonitorPresentationFixtures.oneSoftwareDisplay,
      MonitorPresentationFixtures.oneShadeDisplay,
      MonitorPresentationFixtures.checkingControl,
      MonitorPresentationFixtures.unavailableControl,
      MonitorPresentationFixtures.twoMixedDisplays,
      MonitorPresentationFixtures.fourDisplays,
      MonitorPresentationFixtures.failed,
    ]

    XCTAssertEqual(snapshots.count, 10)

    if case .ready(let four) = MonitorPresentationFixtures.fourDisplays {
      XCTAssertEqual(four.count, 4)
      XCTAssertEqual(Set(four.map(\.id)).count, 4)
    } else {
      XCTFail("Expected a ready four-display fixture")
    }
  }
}

@MainActor
private final class FakeMonitorController: MonitorControlling {
  struct Write: Equatable {
    let value: Double
    let monitorID: MonitorID
    let animated: Bool
    let persist: Bool
  }

  private(set) var currentSnapshot: DisplayControllerSnapshot
  private var snapshotHandler: (@MainActor (DisplayControllerSnapshot) -> Void)?

  private(set) var writes: [Write] = []
  private(set) var refreshCount = 0
  private(set) var retriedMonitorIDs: [MonitorID] = []
  private(set) var teardownCount = 0

  init(snapshot: DisplayControllerSnapshot) {
    currentSnapshot = snapshot
  }

  func setSnapshotHandler(
    _ handler: @escaping @MainActor (DisplayControllerSnapshot) -> Void
  ) {
    snapshotHandler = handler
  }

  func refresh() {
    refreshCount += 1
  }

  func setBrightness(
    _ value: Double,
    for monitorID: MonitorID,
    animated: Bool,
    persist: Bool
  ) {
    writes.append(
      Write(
        value: value,
        monitorID: monitorID,
        animated: animated,
        persist: persist
      )
    )
  }

  func retryControl(for monitorID: MonitorID) {
    retriedMonitorIDs.append(monitorID)
  }

  func teardown() {
    teardownCount += 1
  }

  func emit(_ snapshot: DisplayControllerSnapshot) {
    currentSnapshot = snapshot
    snapshotHandler?(snapshot)
  }
}

private extension Optional where Wrapped == Double {
  static func XCTAssertEqual(
    _ expression: Double?,
    _ expected: Double,
    accuracy: Double,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard let expression else {
      XCTFail("Expected a brightness value", file: file, line: line)
      return
    }
    XCTest.XCTAssertEqual(expression, expected, accuracy: accuracy, file: file, line: line)
  }
}
