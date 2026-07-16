import Foundation

public struct ControlReading: Equatable, Codable, Sendable {
  public let observed: ObservedBrightness
  public let method: DisplayControlMethod
  public let resourceID: PhysicalControlResourceID

  public init(
    observed: ObservedBrightness,
    method: DisplayControlMethod,
    resourceID: PhysicalControlResourceID
  ) {
    self.observed = observed
    self.method = method
    self.resourceID = resourceID
  }
}

public struct ControlWriteReceipt: Equatable, Codable, Sendable {
  public let operationID: EngineOperationID
  public let desired: NormalizedBrightness
  public let outcome: ControlWriteOutcome
  public let completedAt: EngineInstant

  public init(
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

public protocol DisplayControl: AnyObject, Sendable {
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

public enum AppleNativeCapability: Equatable, Codable, Sendable {
  case unavailable(ControlFailure?)
  case readable
  case writeUnvalidated
  case writeValidated
}

public protocol AppleNativeTransport: Sendable {
  func capability(for display: RuntimeDisplayID) async -> AppleNativeCapability
  func readBrightness(for display: RuntimeDisplayID) async throws -> NormalizedBrightness
  func writeBrightness(_ value: NormalizedBrightness, for display: RuntimeDisplayID) async throws
}

public struct DDCValue: Equatable, Codable, Sendable {
  public let current: UInt16
  public let maximum: UInt16

  public init(current: UInt16, maximum: UInt16) {
    self.current = current
    self.maximum = maximum
  }
}

public struct DDCServiceCandidate: Equatable, Codable, Sendable {
  public let serviceID: DDCServiceID
  public let runtimeDisplayID: RuntimeDisplayID?
  public let resourceID: PhysicalControlResourceID
  public let confidence: CapabilityConfidence

  public init(
    serviceID: DDCServiceID,
    runtimeDisplayID: RuntimeDisplayID?,
    resourceID: PhysicalControlResourceID,
    confidence: CapabilityConfidence
  ) {
    self.serviceID = serviceID
    self.runtimeDisplayID = runtimeDisplayID
    self.resourceID = resourceID
    self.confidence = confidence
  }
}

public protocol IOAVTransport: Sendable {
  func discoverServices(
    for snapshot: DisplayTopologySnapshot
  ) async throws -> [DDCServiceCandidate]
  func readVCP(_ code: UInt8, service: DDCServiceID) async throws -> DDCValue
  func writeVCP(_ code: UInt8, value: UInt16, service: DDCServiceID) async throws
  func invalidate(service: DDCServiceID) async
}

public struct GammaTable: Equatable, Codable, Sendable {
  public let red: [Float]
  public let green: [Float]
  public let blue: [Float]

  public init(red: [Float], green: [Float], blue: [Float]) {
    precondition(red.count == green.count && green.count == blue.count)
    self.red = red
    self.green = green
    self.blue = blue
  }

  public var sampleCount: Int {
    red.count
  }
}

public protocol GammaTransport: Sendable {
  func captureBaseline(for display: RuntimeDisplayID) async throws -> GammaTable
  func apply(
    _ table: GammaTable,
    to display: RuntimeDisplayID,
    owner: ControlOwnerID
  ) async throws
  func restoreBaseline(
    _ table: GammaTable,
    to display: RuntimeDisplayID,
    owner: ControlOwnerID
  ) async
}

public protocol ShadeTransport: Sendable {
  func installNeutralShade(
    for display: RuntimeDisplayID,
    owner: ControlOwnerID
  ) async throws
  func setBrightness(
    _ value: NormalizedBrightness,
    for display: RuntimeDisplayID,
    owner: ControlOwnerID
  ) async throws
  func removeShade(for display: RuntimeDisplayID, owner: ControlOwnerID) async
}
