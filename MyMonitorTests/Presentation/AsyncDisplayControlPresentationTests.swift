import XCTest
@testable import MyMonitorPresentation

@MainActor
final class AsyncDisplayControlPresentationTests: XCTestCase {
  func testInitialDetectingStateWithoutCacheRemainsExplicit() {
    let controller = AsyncMonitorController(snapshot: .detecting(cached: []))
    let store = DisplayPresentationStore(controller: controller)

    XCTAssertEqual(store.state, .detecting(cached: []))
    XCTAssertTrue(store.monitors.isEmpty)
  }

  func testCachedMonitorRemainsAdjustableWhileReconfiguring() {
    let controller = AsyncMonitorController(
      snapshot: .detecting(cached: [MonitorPresentationFixtures.hardwareSnapshot])
    )
    let store = DisplayPresentationStore(controller: controller)
    let monitorID = MonitorPresentationFixtures.studioDisplayID

    store.beginBrightnessAdjustment(for: monitorID)
    store.updateBrightness(0.8, for: monitorID)
    store.endBrightnessAdjustment(for: monitorID)

    XCTAssertTrue(store.state.isDetecting)
    XCTAssertEqual(store.monitor(withID: monitorID)?.brightness, 0.8)
    XCTAssertEqual(
      controller.writes,
      [
        AsyncBrightnessWrite(
          value: 0.8,
          monitorID: monitorID,
          animated: false,
          persist: false
        ),
        AsyncBrightnessWrite(
          value: 0.8,
          monitorID: monitorID,
          animated: true,
          persist: true
        ),
      ]
    )
  }

  func testCompletedProbeReplacesDetectingStateWithoutChangingIdentity() {
    let controller = AsyncMonitorController(
      snapshot: .detecting(cached: [MonitorPresentationFixtures.hardwareSnapshot])
    )
    let store = DisplayPresentationStore(controller: controller)

    var completed = MonitorPresentationFixtures.hardwareSnapshot
    completed.brightness = 0.61
    controller.emit(.ready([completed]))

    guard case .ready(let monitors) = store.state else {
      return XCTFail("Expected ready state after probe completion")
    }
    XCTAssertEqual(monitors.map(\.id), [MonitorPresentationFixtures.studioDisplayID])
    XCTAssertEqual(monitors.first?.brightness, 0.61)
  }

  func testNewDisplayAppendsAfterCachedDisplayWhenProbeCompletes() {
    let controller = AsyncMonitorController(
      snapshot: .detecting(cached: [MonitorPresentationFixtures.hardwareSnapshot])
    )
    let store = DisplayPresentationStore(controller: controller)

    controller.emit(
      .ready([
        MonitorPresentationFixtures.softwareSnapshot,
        MonitorPresentationFixtures.hardwareSnapshot,
      ])
    )

    XCTAssertEqual(
      store.monitors.map(\.id),
      [
        MonitorPresentationFixtures.studioDisplayID,
        MonitorPresentationFixtures.dellDisplayID,
      ]
    )
  }
}

@MainActor
private final class AsyncMonitorController: MonitorControlling {
  private(set) var currentSnapshot: DisplayControllerSnapshot
  private var handler: (@MainActor (DisplayControllerSnapshot) -> Void)?
  private(set) var writes: [AsyncBrightnessWrite] = []

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
  ) {
    writes.append(
      AsyncBrightnessWrite(
        value: value,
        monitorID: monitorID,
        animated: animated,
        persist: persist
      )
    )
  }

  func retryControl(for monitorID: MonitorID) {}
  func teardown() {}

  func emit(_ snapshot: DisplayControllerSnapshot) {
    currentSnapshot = snapshot
    handler?(snapshot)
  }
}

private struct AsyncBrightnessWrite: Equatable {
  let value: Double
  let monitorID: MonitorID
  let animated: Bool
  let persist: Bool
}
