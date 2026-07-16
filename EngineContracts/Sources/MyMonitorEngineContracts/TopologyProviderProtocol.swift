public enum DisplayTopologyEvent: Equatable, Codable, Sendable {
  case connected(RuntimeDisplayID)
  case disconnected(RuntimeDisplayID)
  case modeChanged(RuntimeDisplayID?)
  case layoutChanged
  case wake
}

public protocol DisplayTopologyProviding: Sendable {
  func snapshot(reason: ReconfigurationReason) async throws -> DisplayTopologySnapshot
  func events() -> AsyncStream<DisplayTopologyEvent>
}
