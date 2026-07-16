import XCTest
@testable import MyMonitorPresentation

final class FrontendFixtureCatalogTests: XCTestCase {
  func testEightDisplayStressFixtureHasStableUniqueIdentity() {
    guard case .ready(let displays) = MonitorPresentationFixtures.eightDisplays else {
      return XCTFail("Expected an eight-display ready fixture")
    }

    XCTAssertEqual(displays.count, 8)
    XCTAssertEqual(Set(displays.map(\.id)).count, 8)
    XCTAssertEqual(displays.first?.id, MonitorPresentationFixtures.studioDisplayID)
    XCTAssertEqual(displays.last?.id, MonitorID(rawValue: 1009))
  }

  func testEightDisplayFixtureCoversMixedCapabilityStates() {
    guard case .ready(let displays) = MonitorPresentationFixtures.eightDisplays else {
      return XCTFail("Expected an eight-display ready fixture")
    }

    XCTAssertTrue(displays.contains { $0.control == .available(.hardware) })
    XCTAssertTrue(displays.contains { $0.control == .available(.software) })
    XCTAssertTrue(displays.contains { $0.control == .available(.shade) })
    XCTAssertTrue(displays.contains { $0.control == .checking })
    XCTAssertTrue(
      displays.contains {
        if case .unavailable = $0.control { return true }
        return false
      }
    )
  }

  func testCriticalTopLevelFixturesRemainExplicit() {
    XCTAssertEqual(MonitorPresentationFixtures.detectingWithoutCache, .detecting(cached: []))
    XCTAssertEqual(MonitorPresentationFixtures.empty, .ready([]))

    if case .failed(let message, let canRetry) = MonitorPresentationFixtures.failed {
      XCTAssertFalse(message.isEmpty)
      XCTAssertTrue(canRetry)
    } else {
      XCTFail("Expected a failed fixture")
    }
  }

  func testLongNameFixtureExercisesTruncationInput() {
    guard case .ready(let displays) = MonitorPresentationFixtures.longNameDisplay,
      let display = displays.first
    else {
      return XCTFail("Expected a long-name ready fixture")
    }

    XCTAssertGreaterThan(display.name.count, 40)
    XCTAssertNotNil(display.brightness)
  }
}
