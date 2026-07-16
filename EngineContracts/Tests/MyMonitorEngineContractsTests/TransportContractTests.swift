import XCTest
@testable import MyMonitorEngineContracts

final class TransportContractTests: XCTestCase {
  func testFakeAppleTransportRecordsWritesDeterministically() async throws {
    let display = RuntimeDisplayID(rawValue: 7)
    let transport = FakeAppleNativeTransport()
    await transport.configureCapability(.writeUnvalidated, for: display)
    await transport.configureBrightness(.clamping(0.6), for: display)

    let capability = await transport.capability(for: display)
    let initialBrightness = try await transport.readBrightness(for: display)
    XCTAssertEqual(capability, .writeUnvalidated)
    XCTAssertEqual(initialBrightness, .clamping(0.6))

    try await transport.writeBrightness(.clamping(0.4), for: display)
    let writes = await transport.recordedWrites()
    XCTAssertEqual(
      writes,
      [FakeAppleNativeTransport.Write(display: display, value: .clamping(0.4))]
    )
  }

  func testFakeIOAVTransportSeparatesDiscoveryReadWriteAndInvalidation() async throws {
    let display = RuntimeDisplayID(rawValue: 12)
    let service = DDCServiceID(rawValue: "service-12")
    let candidate = DDCServiceCandidate(
      serviceID: service,
      runtimeDisplayID: display,
      resourceID: .ioav("resource-12"),
      confidence: .high
    )
    let transport = FakeIOAVTransport()
    await transport.configureCandidates([candidate])
    await transport.configureValue(DDCValue(current: 128, maximum: 255), for: service)

    let snapshot = DisplayTopologySnapshot(
      capturedAt: .zero,
      signature: TopologySignature(rawValue: "topology"),
      displays: [],
      mirrorGroups: []
    )

    let discovered = try await transport.discoverServices(for: snapshot)
    let read = try await transport.readVCP(0x10, service: service)
    XCTAssertEqual(discovered, [candidate])
    XCTAssertEqual(read, DDCValue(current: 128, maximum: 255))

    try await transport.writeVCP(0x10, value: 64, service: service)
    await transport.invalidate(service: service)

    let writes = await transport.recordedWrites()
    let invalidated = await transport.invalidatedServices()
    XCTAssertEqual(
      writes,
      [FakeIOAVTransport.Write(code: 0x10, value: 64, service: service)]
    )
    XCTAssertEqual(invalidated, [service])
  }
}
