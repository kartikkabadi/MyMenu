public enum ControlHealth: Equatable, Codable, Sendable {
  case unknown
  case healthy
  case provisional
  case recovering
  case degraded(ControlFailure)
  case unavailable(ControlFailure)
}
