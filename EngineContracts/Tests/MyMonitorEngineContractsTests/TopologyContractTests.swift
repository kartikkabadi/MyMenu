import XCTest
@testable import MyMonitorEngineContracts

final class TopologyContractTests: XCTestCase {
  func testProviderPublishesSnapshotAndEventsDeterministically() async throws {
    let display = RuntimeDisplayID(rawValue: 44)
    let snapshot = DisplayTopologySnapshot(
      capturedAt: .zero,
      signature: TopologySignature(rawValue: "one"),
      displays: [
        RuntimeDisplayDescriptor(
          runtimeID: display,
          name: "Fixture",
          isBuiltIn: false,
          isOnline: true,
          vendorID: nil,
          productID: nil,
          serialNumber: nil,
          edidDigest: nil,
          connection: ConnectionEvidence(transport: "fixture")
        ),
      ],
      mirrorGroups: []
    )
    let provider = FakeDisplayTopologyProvider(snapshot: snapshot)
    let stream = provider.events()
    var iterator = stream.makeAsyncIterator()

    await provider.send(.connected(display))

    let returned = try await provider.snapshot(reason: .coldLaunch)
    let event = await iterator.next()
    XCTAssertEqual(returned, snapshot)
    XCTAssertEqual(event, .connected(display))
    await provider.finish()
  }
}
