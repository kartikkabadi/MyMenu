import XCTest
@testable import MyMonitorPresentation

final class GammaHoldRegistryTests: XCTestCase {
  func testRegistryKeepsIndependentBrightnessForMultipleDisplays() {
    var registry = GammaHoldRegistry<Int>()

    registry.setBrightness(0.35, for: 1)
    registry.setBrightness(0.8, for: 2)

    assertBrightness(registry.brightnessByID[1], equals: 0.35)
    assertBrightness(registry.brightnessByID[2], equals: 0.8)
  }

  func testReplacingOneHoldDoesNotChangeAnother() {
    var registry = GammaHoldRegistry<Int>()
    registry.setBrightness(0.35, for: 1)
    registry.setBrightness(0.8, for: 2)

    registry.setBrightness(0.55, for: 1)

    assertBrightness(registry.brightnessByID[1], equals: 0.55)
    assertBrightness(registry.brightnessByID[2], equals: 0.8)
  }

  func testRemovingOneHoldPreservesAllOthers() {
    var registry = GammaHoldRegistry<Int>()
    registry.setBrightness(0.35, for: 1)
    registry.setBrightness(0.8, for: 2)

    registry.removeBrightness(for: 1)

    XCTAssertNil(registry.brightnessByID[1])
    assertBrightness(registry.brightnessByID[2], equals: 0.8)
  }

  func testRegistryClampsBrightnessToNormalizedBounds() {
    var registry = GammaHoldRegistry<Int>()

    registry.setBrightness(-0.2, for: 1)
    registry.setBrightness(1.4, for: 2)

    assertBrightness(registry.brightnessByID[1], equals: 0)
    assertBrightness(registry.brightnessByID[2], equals: 1)
  }
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
