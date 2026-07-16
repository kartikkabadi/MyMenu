public enum ReconfigurationReason: Hashable, Codable, Sendable {
  case coldLaunch
  case firstConnection
  case transientReconnect(continuity: ContinuityID)
  case wake(continuity: ContinuityID)
  case topologyChanged
  case displayModeChanged
  case userRetry
  case methodChanged
  case profileChanged
  case testFixture(String)
}

public enum SuspensionReason: String, Codable, Sendable {
  case sleep
  case transientDisconnect
  case topologyChange
  case modeChange
  case methodReplacement
  case terminal
}

public enum BrightnessAdjustmentKind: String, Codable, Sendable {
  case absolute
  case relative
  case lifecycleRestore
  case rangeClamp
}
