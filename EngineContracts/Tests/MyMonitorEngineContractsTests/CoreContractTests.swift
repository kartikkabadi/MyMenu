import XCTest
@testable import MyMonitorEngineContracts

final class CoreContractTests: XCTestCase {
  func testMethodsMapToDistinctControlDomains() {
    XCTAssertEqual(DisplayControlMethod.appleNative.domain, .hardware)
    XCTAssertEqual(DisplayControlMethod.ddc.domain, .hardware)
    XCTAssertEqual(DisplayControlMethod.gamma.domain, .gamma)
    XCTAssertEqual(DisplayControlMethod.shade.domain, .shade)
  }

  func testExplicitPreferencesNeverCrossFamilies() {
    XCTAssertTrue(ControlPreference.hardware.permits(.appleNative))
    XCTAssertTrue(ControlPreference.hardware.permits(.ddc))
    XCTAssertFalse(ControlPreference.hardware.permits(.gamma))
    XCTAssertFalse(ControlPreference.hardware.permits(.shade))

    XCTAssertFalse(ControlPreference.software.permits(.appleNative))
    XCTAssertFalse(ControlPreference.software.permits(.ddc))
    XCTAssertTrue(ControlPreference.software.permits(.gamma))
    XCTAssertTrue(ControlPreference.software.permits(.shade))
  }

  func testDesiredBrightnessIsIndependentByDomain() {
    var desired = DesiredBrightnessSet(hardware: .clamping(0.25), gamma: .clamping(0.5), shade: .clamping(0.75))

    desired[.gamma] = .clamping(0.9)

    XCTAssertEqual(desired[.hardware], .clamping(0.25))
    XCTAssertEqual(desired[.gamma], .clamping(0.9))
    XCTAssertEqual(desired[.shade], .clamping(0.75))
  }

  func testAcceptedUnverifiedCannotManufactureObservedState() {
    let operationID = EngineOperationID()
    let status = BrightnessWriteStatus.acceptedUnverified(
      operationID: operationID,
      desired: .clamping(0.42)
    )

    guard case let .acceptedUnverified(returnedID, desired) = status else {
      return XCTFail("Expected accepted-unverified status")
    }
    XCTAssertEqual(returnedID, operationID)
    XCTAssertEqual(desired, .clamping(0.42))
  }

  func testAppliedCarriesEvidenceBackedObservation() {
    let observation = ObservedBrightness(
      value: .clamping(0.63),
      source: .postWriteVerification,
      observedAt: EngineInstant(rawValue: 10),
      confidence: .exact
    )
    let status = BrightnessWriteStatus.applied(
      operationID: EngineOperationID(),
      observed: observation
    )

    guard case let .applied(_, returnedObservation) = status else {
      return XCTFail("Expected applied status")
    }
    XCTAssertEqual(returnedObservation, observation)
  }

  func testNormalizedBrightnessRejectsInvalidDecodedValues() throws {
    let decoder = JSONDecoder()

    XCTAssertThrowsError(try decoder.decode(NormalizedBrightness.self, from: Data("1.1".utf8)))
    XCTAssertThrowsError(try decoder.decode(NormalizedBrightness.self, from: Data("-0.1".utf8)))
    XCTAssertNil(NormalizedBrightness(rawValue: .nan))
    XCTAssertEqual(NormalizedBrightness.clamping(1.5), .brightest)
  }

  func testContinuityTargetRequiresCompatibleDomain() {
    let target = ConfirmedContinuityTarget(
      domain: .hardware,
      method: .ddc,
      resourceID: .ioav("service"),
      value: .clamping(0.7),
      evidence: .ddcRead,
      establishedAt: .zero
    )

    XCTAssertEqual(target.domain, .hardware)
    XCTAssertEqual(target.method, .ddc)
    XCTAssertEqual(target.value, .clamping(0.7))
  }
}
