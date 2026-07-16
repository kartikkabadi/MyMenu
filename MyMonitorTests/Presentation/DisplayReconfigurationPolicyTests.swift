import XCTest
@testable import MyMonitorPresentation

final class DisplayReconfigurationPolicyTests: XCTestCase {
  func testLiveBrightnessWinsOverStalePersistedAndProbedValues() {
    XCTAssertEqual(
      DisplayReconfigurationPolicy.resolvedBrightness(
        live: 0.82,
        persisted: 0.41,
        probed: 0.27,
        allowedRange: 0...1
      ),
      0.82,
      accuracy: 0.0001
    )
  }

  func testPersistedBrightnessWinsWhenNoLiveRowExists() {
    XCTAssertEqual(
      DisplayReconfigurationPolicy.resolvedBrightness(
        live: nil,
        persisted: 0.63,
        probed: 0.27,
        allowedRange: 0...1
      ),
      0.63,
      accuracy: 0.0001
    )
  }

  func testProbedBrightnessSeedsFirstRun() {
    XCTAssertEqual(
      DisplayReconfigurationPolicy.resolvedBrightness(
        live: nil,
        persisted: nil,
        probed: 0.46,
        allowedRange: 0...1
      ),
      0.46,
      accuracy: 0.0001
    )
  }

  func testMissingValuesDefaultToFullBrightness() {
    XCTAssertEqual(
      DisplayReconfigurationPolicy.resolvedBrightness(
        live: nil,
        persisted: nil,
        probed: nil,
        allowedRange: 0...1
      ),
      1,
      accuracy: 0.0001
    )
  }

  func testLatestConfiguredRangeClampsInstalledValue() {
    XCTAssertEqual(
      DisplayReconfigurationPolicy.resolvedBrightness(
        live: 0.91,
        persisted: nil,
        probed: nil,
        allowedRange: 0.2...0.75
      ),
      0.75,
      accuracy: 0.0001
    )
  }

  func testRemovedIDsAreComputedImmediatelyFromInstalledAndOnlineSets() {
    XCTAssertEqual(
      DisplayReconfigurationPolicy.removedIDs(
        installed: Set([1001, 1002, 1003]),
        online: Set([1001, 1003, 1004])
      ),
      Set([1002])
    )
  }
}
