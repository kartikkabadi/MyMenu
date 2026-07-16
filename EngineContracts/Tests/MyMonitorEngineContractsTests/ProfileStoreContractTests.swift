import XCTest
@testable import MyMonitorEngineContracts

final class ProfileStoreContractTests: XCTestCase {
  func testFakeStorePreservesVersionedSnapshots() async throws {
    let initial = DisplayProfileSnapshot(schemaVersion: 3, profiles: [])
    let report = MigrationReport(
      sourceVersion: 2,
      targetVersion: 3,
      migratedProfileCount: 1,
      preservedLegacyRecordCount: 0,
      warnings: []
    )
    let store = FakeDisplayProfileStore(snapshot: initial, migrationReport: report)
    let profile = DisplayProfile(
      id: PersistentDisplayID(rawValue: "display"),
      desiredBrightness: DesiredBrightnessSet(hardware: .clamping(0.55)),
      requestedPreference: .hardware
    )
    let updated = DisplayProfileSnapshot(schemaVersion: 3, profiles: [profile])

    try await store.saveSnapshot(updated)

    let loaded = try await store.loadSnapshot()
    let saves = await store.savedSnapshots()
    XCTAssertEqual(loaded, updated)
    XCTAssertEqual(saves, [updated])
  }
}
