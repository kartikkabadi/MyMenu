import Foundation

struct NormalizedBrightness: RawRepresentable, Hashable, Comparable, Codable, Sendable {
  let rawValue: Double

  init?(rawValue: Double) {
    guard rawValue.isFinite, (0...1).contains(rawValue) else { return nil }
    self.rawValue = rawValue
  }

  static let darkest = NormalizedBrightness(rawValue: 0)!
  static let brightest = NormalizedBrightness(rawValue: 1)!

  static func clamping(_ value: Double) -> NormalizedBrightness {
    NormalizedBrightness(rawValue: min(max(value.isFinite ? value : 0, 0), 1))!
  }

  static func < (lhs: NormalizedBrightness, rhs: NormalizedBrightness) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(Double.self)
    guard let brightness = NormalizedBrightness(rawValue: value) else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Brightness must be finite and inside 0...1"
      )
    }
    self = brightness
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

struct RuntimeDisplayID: RawRepresentable, Hashable, Codable, Sendable {
  let rawValue: UInt32

  init(rawValue: UInt32) {
    self.rawValue = rawValue
  }
}

struct PersistentDisplayID: RawRepresentable, Hashable, Codable, Sendable {
  let rawValue: String

  init(rawValue: String) {
    self.rawValue = rawValue
  }
}

struct DisplayGroupID: RawRepresentable, Hashable, Codable, Sendable {
  let rawValue: String

  init(rawValue: String) {
    self.rawValue = rawValue
  }
}

struct DDCServiceID: RawRepresentable, Hashable, Codable, Sendable {
  let rawValue: String

  init(rawValue: String) {
    self.rawValue = rawValue
  }
}

struct OwnerToken: RawRepresentable, Hashable, Codable, Sendable {
  let rawValue: UUID

  init(rawValue: UUID = UUID()) {
    self.rawValue = rawValue
  }
}

struct EngineOperationID: RawRepresentable, Hashable, Codable, Sendable {
  let rawValue: UUID

  init(rawValue: UUID = UUID()) {
    self.rawValue = rawValue
  }
}

enum DisplayControlMethod: String, Codable, Sendable, CaseIterable {
  case appleNative
  case ddc
  case gamma
  case shade

  var domain: BrightnessControlDomain {
    switch self {
    case .appleNative, .ddc:
      .hardware
    case .gamma:
      .gamma
    case .shade:
      .shade
    }
  }
}

enum BrightnessControlDomain: String, Codable, Sendable, CaseIterable {
  case hardware
  case gamma
  case shade
}

enum ControlPreference: String, Codable, Sendable, CaseIterable {
  case automatic
  case hardware
  case software
  case shade

  func permits(_ method: DisplayControlMethod) -> Bool {
    switch self {
    case .automatic:
      true
    case .hardware:
      method.domain == .hardware
    case .software:
      method == .gamma || method == .shade
    case .shade:
      method == .shade
    }
  }
}

struct DesiredBrightnessSet: Equatable, Codable, Sendable {
  var hardware: NormalizedBrightness?
  var gamma: NormalizedBrightness?
  var shade: NormalizedBrightness?

  init(
    hardware: NormalizedBrightness? = nil,
    gamma: NormalizedBrightness? = nil,
    shade: NormalizedBrightness? = nil
  ) {
    self.hardware = hardware
    self.gamma = gamma
    self.shade = shade
  }

  subscript(domain: BrightnessControlDomain) -> NormalizedBrightness? {
    get {
      switch domain {
      case .hardware: hardware
      case .gamma: gamma
      case .shade: shade
      }
    }
    set {
      switch domain {
      case .hardware: hardware = newValue
      case .gamma: gamma = newValue
      case .shade: shade = newValue
      }
    }
  }
}

enum ObservationSource: String, Codable, Sendable {
  case appleNativeReadback
  case ddcRead
  case postWriteVerification
  case gammaOwnership
  case shadeOwnership
}

enum ObservationConfidence: String, Codable, Sendable {
  case exact
  case high
  case qualified
}

struct ObservedBrightness: Equatable, Codable, Sendable {
  let value: NormalizedBrightness
  let source: ObservationSource
  let observedAt: EngineInstant
  let confidence: ObservationConfidence

  init(
    value: NormalizedBrightness,
    source: ObservationSource,
    observedAt: EngineInstant,
    confidence: ObservationConfidence
  ) {
    self.value = value
    self.source = source
    self.observedAt = observedAt
    self.confidence = confidence
  }
}

enum PhysicalControlResourceID: Hashable, Codable, Sendable {
  case appleNative(String)
  case ioav(String)
  case gamma(RuntimeDisplayID)
  case shade(RuntimeDisplayID)
  case grouped(String)
}

struct ConfirmedContinuityTarget: Equatable, Codable, Sendable {
  let domain: BrightnessControlDomain
  let method: DisplayControlMethod
  let resourceID: PhysicalControlResourceID
  let value: NormalizedBrightness
  let evidence: ObservationSource
  let establishedAt: EngineInstant

  init(
    domain: BrightnessControlDomain,
    method: DisplayControlMethod,
    resourceID: PhysicalControlResourceID,
    value: NormalizedBrightness,
    evidence: ObservationSource,
    establishedAt: EngineInstant
  ) {
    precondition(method.domain == domain, "Continuity targets must use compatible method/domain semantics")
    self.domain = domain
    self.method = method
    self.resourceID = resourceID
    self.value = value
    self.evidence = evidence
    self.establishedAt = establishedAt
  }
}

enum ControlFailure: Error, Equatable, Codable, Sendable {
  case noService
  case ambiguousServiceMatch
  case readTimeout
  case writeTimeout
  case invalidResponse
  case invalidRange(current: UInt16?, maximum: UInt16?)
  case writeRejected(code: Int32?)
  case verificationMismatch(requested: NormalizedBrightness, observed: NormalizedBrightness)
  case staleResource
  case topologyChanged
  case displayDisconnected
  case baselineUnavailableForRelativeAdjustment
  case capabilityUnavailable(DisplayControlMethod)
  case persistenceUnavailable
  case privateSymbolUnavailable
  case unsupportedArchitecture
  case superseded
  case cancelled
  case terminal
}

enum BrightnessWriteStatus: Equatable, Codable, Sendable {
  case idle
  case queued(operationID: EngineOperationID)
  case writing(operationID: EngineOperationID, attempt: Int)
  case acceptedUnverified(operationID: EngineOperationID, desired: NormalizedBrightness)
  case applied(operationID: EngineOperationID, observed: ObservedBrightness)
  case failed(operationID: EngineOperationID, failure: ControlFailure, desired: NormalizedBrightness)
}

enum ControlWriteOutcome: Equatable, Codable, Sendable {
  case acceptedUnverified
  case applied(ObservedBrightness)
}

enum CapabilityState: String, Codable, Sendable {
  case unknown
  case available
  case unavailable
  case degraded
  case requiresUserWriteValidation
}

enum CapabilitySource: String, Codable, Sendable {
  case explicitQuery
  case nonMutatingRead
  case topologyEvidence
  case userWriteValidation
  case qualifiedCompatibilityRecord
}

enum CapabilityConfidence: String, Codable, Sendable {
  case low
  case medium
  case high
  case exact
}

struct ControlCapabilityEvidence: Equatable, Codable, Sendable {
  let method: DisplayControlMethod
  let state: CapabilityState
  let observedAt: EngineInstant
  let topologySignature: TopologySignature
  let source: CapabilitySource
  let confidence: CapabilityConfidence
  let failure: ControlFailure?
}
