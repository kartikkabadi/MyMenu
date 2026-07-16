public struct BrightnessOperationContext: Equatable, Codable, Sendable {
  public let operationID: EngineOperationID
  public let engineGeneration: EngineGeneration
  public let sessionGeneration: SessionGeneration
  public let resourceID: PhysicalControlResourceID
  public let reason: ReconfigurationReason
  public let adjustmentKind: BrightnessAdjustmentKind
  public let startedAt: EngineInstant

  public init(
    operationID: EngineOperationID,
    engineGeneration: EngineGeneration,
    sessionGeneration: SessionGeneration,
    resourceID: PhysicalControlResourceID,
    reason: ReconfigurationReason,
    adjustmentKind: BrightnessAdjustmentKind,
    startedAt: EngineInstant
  ) {
    self.operationID = operationID
    self.engineGeneration = engineGeneration
    self.sessionGeneration = sessionGeneration
    self.resourceID = resourceID
    self.reason = reason
    self.adjustmentKind = adjustmentKind
    self.startedAt = startedAt
  }
}

public struct ResumeContext: Equatable, Codable, Sendable {
  public let reason: ReconfigurationReason
  public let engineGeneration: EngineGeneration
  public let sessionGeneration: SessionGeneration
  public let topologySignature: TopologySignature
  public let continuityEpoch: ContinuityEpoch

  public init(
    reason: ReconfigurationReason,
    engineGeneration: EngineGeneration,
    sessionGeneration: SessionGeneration,
    topologySignature: TopologySignature,
    continuityEpoch: ContinuityEpoch
  ) {
    self.reason = reason
    self.engineGeneration = engineGeneration
    self.sessionGeneration = sessionGeneration
    self.topologySignature = topologySignature
    self.continuityEpoch = continuityEpoch
  }
}
