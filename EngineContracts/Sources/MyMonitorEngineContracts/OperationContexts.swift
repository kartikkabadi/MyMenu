import Foundation

struct BrightnessOperationContext: Equatable, Codable, Sendable {
  let operationID: EngineOperationID
  let engineGeneration: EngineGeneration
  let sessionGeneration: SessionGeneration
  let resourceID: PhysicalControlResourceID
  let reason: ReconfigurationReason
  let adjustmentKind: BrightnessAdjustmentKind
  let startedAt: EngineInstant
}

struct ResumeContext: Equatable, Codable, Sendable {
  let reason: ReconfigurationReason
  let engineGeneration: EngineGeneration
  let sessionGeneration: SessionGeneration
  let topologySignature: TopologySignature
  let continuityEpoch: ContinuityEpoch
}
