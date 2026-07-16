package protocol DisplayProfileStoring: Sendable {
  func loadSnapshot() async throws -> DisplayProfileSnapshot
  func saveSnapshot(_ snapshot: DisplayProfileSnapshot) async throws
  func migrateLegacyIfNeeded(
    topology: DisplayTopologySnapshot
  ) async throws -> MigrationReport
}
