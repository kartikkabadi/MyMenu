import Foundation

struct ControlReading: Equatable, Codable, Sendable {
  let observed: ObservedBrightness
  let method: DisplayControlMethod
  let resourceID: PhysicalControlResourceID
}

struct ControlWriteReceipt: Equatable, Codable, Sendable {
  let operationID: EngineOperationID
  let desired: NormalizedBrightness
  let outcome: ControlWriteOutcome
  let completedAt: EngineInstant

  init(
    operationID: EngineOperationID,
    desired: NormalizedBrightness,
    outcome: ControlWriteOutcome,
    completedAt: EngineInstant
  ) {
    self.operationID = operationID
    self.desired = desired
    self.outcome = outcome
    self.completedAt = completedAt
  }
}

protocol DisplayControl: AnyObject, Sendable {
  var method: DisplayControlMethod { get }
  var domain: BrightnessControlDomain { get }
  var resourceID: PhysicalControlResourceID { get }

  func readBrightness() async throws -> ControlReading
  func writeBrightness(
    _ normalized: NormalizedBrightness,
    operation: BrightnessOperationContext
  ) async throws -> ControlWriteReceipt
  func neutralizeForTransition(operation: BrightnessOperationContext) async throws
  func suspend(reason: SuspensionReason) async
  func resume(context: ResumeContext) async throws
  func teardown() async
}

enum AppleNativeCapability: Equatable, Codable, Sendable {
  case unavailable(ControlFailure?)
  case readable
  case writeUnvalidated
  case writeValidated
}

protocol AppleNativeTransport: Sendable {
  func capability(for display: RuntimeDisplayID) async -> AppleNativeCapability
  func readBrightness(for display: RuntimeDisplayID) async throws -> NormalizedBrightness
  func writeBrightness(_ value: NormalizedBrightness, for display: RuntimeDisplayID) async throws
}

struct DDCValue: Equatable, Codable, Sendable {
  let current: UInt16
  let maximum: UInt16
}

struct DDCServiceCandidate: Equatable, Codable, Sendable {
  let serviceID: DDCServiceID
  let runtimeDisplayID: RuntimeDisplayID?
  let resourceID: PhysicalControlResourceID
  let confidence: CapabilityConfidence
}

protocol IOAVTransport: Sendable {
  func discoverServices(for snapshot: DisplayTopologySnapshot) async throws -> [DDCServiceCandidate]
  func readVCP(_ code: UInt8, service: DDCServiceID) async throws -> DDCValue
  func writeVCP(_ code: UInt8, value: UInt16, service: DDCServiceID) async throws
  func invalidate(service: DDCServiceID) async
}

struct GammaTable: Equatable, Codable, Sendable {
  let red: [Float]
  let green: [Float]
  let blue: [Float]

  init(red: [Float], green: [Float], blue: [Float]) {
    precondition(red.count == green.count && green.count == blue.count)
    self.red = red
    self.green = green
    self.blue = blue
  }

  var sampleCount: Int {
    red.count
  }
}

protocol GammaTransport: Sendable {
  func captureBaseline(for display: RuntimeDisplayID) async throws -> GammaTable
  func apply(_ table: GammaTable, to display: RuntimeDisplayID, owner: OwnerToken) async throws
  func restoreBaseline(
    _ table: GammaTable,
    to display: RuntimeDisplayID,
    owner: OwnerToken
  ) async
}

protocol ShadeTransport: Sendable {
  func installNeutralShade(for display: RuntimeDisplayID, owner: OwnerToken) async throws
  func setBrightness(_ value: NormalizedBrightness, for display: RuntimeDisplayID, owner: OwnerToken) async throws
  func removeShade(for display: RuntimeDisplayID, owner: OwnerToken) async
}
