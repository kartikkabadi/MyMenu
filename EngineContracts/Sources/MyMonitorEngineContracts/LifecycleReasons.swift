import Foundation

enum ReconfigurationReason: Hashable, Codable, Sendable {
  case coldLaunch
  case firstConnection
  case transientReconnect(continuity: ContinuityToken)
  case wake(continuity: ContinuityToken)
  case topologyChanged
  case displayModeChanged
  case userRetry
  case methodChanged
  case profileChanged
  case testFixture(String)
}

enum SuspensionReason: String, Codable, Sendable {
  case sleep
  case transientDisconnect
  case topologyChange
  case modeChange
  case methodReplacement
  case terminal
}

enum BrightnessAdjustmentKind: String, Codable, Sendable {
  case absolute
  case relative
  case lifecycleRestore
  case rangeClamp
}

enum ControlHealth: Equatable, Codable, Sendable {
  case unknown
  case healthy
  case provisional
  case recovering
  case degraded(ControlFailure)
  case unavailable(ControlFailure)
}
