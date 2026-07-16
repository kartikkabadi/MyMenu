import XCTest
@testable import MyMonitorPresentation

final class GammaHoldRegistryTests: XCTestCase {
  func testRegistryKeepsIndependentBrightnessForMultipleDisplays() {
    var registry = GammaHoldRegistry<Int>()

    registry.setBrightness(0.35, for: 1)
    registry.setBrightness(0.8, for: 2)

    XCTAssertEqual(registry.brightnessByID[1], 0.35, accuracy: 0.0001)
    XCTAssertEqual(registry.brightnessByID[2], 0.8, accuracy: 0.0001)
  }

  func testReplacingOneHoldDoesNotChangeAnother() {
    var registry = GammaHoldRegistry<Int>()
    registry.setBrightness(0.35, for: 1)
    registry.setBrightness(0.8, for: 2)

    registry.setBrightness(0.55, for: 1)

    XCTAssertEqual(registry.brightnessByID[1], 0.55, accuracy: 0.0001)
    XCTAssertEqual(registry.brightnessByID[2], 0.8, accuracy: 0.0001)
  }

  func testRemovingOneHoldPreservesAllOthers() {
    var registry = GammaHoldRegistry<Int>()
    registry.setBrightness(0.35, for: 1)
    registry.setBrightness(0.8, for: 2)

    registry.removeBrightness(for: 1)

    XCTAssertNil(registry.brightnessByID[1])
    XCTAssertEqual(registry.brightnessByID[2], 0.8, accuracy: 0.0001)
  }

  func testRegistryClampsBrightnessToNormalizedBounds() {
    var registry = GammaHoldRegistry<Int>()

    registry.setBrightness(-0.2, for: 1)
    registry.setBrightness(1.4, for: 2)

    XCTAssertEqual(registry.brightnessByID[1], 0, accuracy: 0.0001)
    XCTAssertEqual(registry.brightnessByID[2], 1, accuracy: 0.0001)
  }
}
