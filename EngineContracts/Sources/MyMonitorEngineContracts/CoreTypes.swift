import Foundation

public struct NormalizedBrightness: RawRepresentable, Hashable, Comparable, Codable, Sendable {
  public let rawValue: Double

  public init?(rawValue: Double) {
    guard rawValue.isFinite, (0...1).contains(rawValue) else { return nil }
    self.rawValue = rawValue
  }

  public static let darkest = NormalizedBrightness(rawValue: 0)!
  public static let brightest = NormalizedBrightness(rawValue: 1)!

  public static func clamping(_ value: Double) -> NormalizedBrightness {
    if value.isNaN || value == -.infinity {
      return .darkest
    }
    if value == .infinity {
      return .brightest
    }
    return NormalizedBrightness(rawValue: min(max(value, 0), 1))!
  }

  public static func < (lhs: NormalizedBrightness, rhs: NormalizedBrightness) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public init(from decoder: Decoder) throws {
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

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

public struct RuntimeDisplayID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }
}

public struct PersistentDisplayID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct DisplayGroupID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct DDCServiceID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct ControlOwnerID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: UUID

  public init(rawValue: UUID = UUID()) {
    self.rawValue = rawValue
  }
}

public struct EngineOperationID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: UUID

  public init(rawValue: UUID = UUID()) {
    self.rawValue = rawValue
  }
}

public enum DisplayControlMethod: String, Codable, Sendable, CaseIterable {
  case appleNative
  case ddc
  case gamma
  case shade

  public var domain: BrightnessControlDomain {
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

public enum BrightnessControlDomain: String, Codable, Sendable, CaseIterable {
  case hardware
  case gamma
  case shade
}

public enum ControlPreference: String, Codable, Sendable, CaseIterable {
  case automatic
  case hardware
  case software
  case shade

  public func permits(_ method: DisplayControlMethod) -> Bool {
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

public struct DesiredBrightnessSet: Equatable, Codable, Sendable {
  public var hardware: NormalizedBrightness?
  public var gamma: NormalizedBrightness?
  public var shade: NormalizedBrightness?

  public init(
    hardware: NormalizedBrightness? = nil,
    gamma: NormalizedBrightness? = nil,
    shade: NormalizedBrightness? = nil
  ) {
    self.hardware = hardware
    self.gamma = gamma
    self.shade = shade
  }

  public subscript(domain: BrightnessControlDomain) -> NormalizedBrightness? {
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

public enum ObservationSource: String, Codable, Sendable {
  case appleNativeReadback
  case ddcRead
  case postWriteVerification
  case gammaOwnership
  case shadeOwnership
}

public enum ObservationConfidence: String, Codable, Sendable {
  case exact
  case high
  case qualified
}

public struct ObservedBrightness: Equatable, Codable, Sendable {
  public let value: NormalizedBrightness
  public let source: ObservationSource
  public let observedAt: EngineInstant
  public let confidence: ObservationConfidence

  public init(
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

public enum PhysicalControlResourceID: Hashable, Codable, Sendable {
  case appleNative(String)
  case ioav(String)
  case gamma(RuntimeDisplayID)
  case shade(RuntimeDisplayID)
  case grouped(String)
}

public struct ConfirmedContinuityTarget: Equatable, Codable, Sendable {
  public let domain: BrightnessControlDomain
  public let method: DisplayControlMethod
  public let resourceID: PhysicalControlResourceID
  public let value: NormalizedBrightness
  public let evidence: ObservationSource
  public let establishedAt: EngineInstant

  public init(
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

public enum ControlFailure: Error, Equatable, Codable, Sendable {
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

public enum BrightnessWriteStatus: Equatable, Codable, Sendable {
  case idle
  case queued(operationID: EngineOperationID)
  case writing(operationID: EngineOperationID, attempt: Int)
  case acceptedUnverified(operationID: EngineOperationID, desired: NormalizedBrightness)
  case applied(operationID: EngineOperationID, observed: ObservedBrightness)
  case failed(operationID: EngineOperationID, failure: ControlFailure, desired: NormalizedBrightness)
}

public enum ControlWriteOutcome: Equatable, Codable, Sendable {
  case acceptedUnverified
  case applied(ObservedBrightness)
}

public enum CapabilityState: String, Codable, Sendable {
  case unknown
  case available
  case unavailable
  case degraded
  case requiresUserWriteValidation
}

public enum CapabilitySource: String, Codable, Sendable {
  case explicitQuery
  case nonMutatingRead
  case topologyEvidence
  case userWriteValidation
  case qualifiedCompatibilityRecord
}

public enum CapabilityConfidence: String, Codable, Sendable {
  case low
  case medium
  case high
  case exact
}

public struct ControlCapabilityEvidence: Equatable, Codable, Sendable {
  public let method: DisplayControlMethod
  public let state: CapabilityState
  public let observedAt: EngineInstant
  public let topologySignature: TopologySignature
  public let source: CapabilitySource
  public let confidence: CapabilityConfidence
  public let failure: ControlFailure?

  public init(
    method: DisplayControlMethod,
    state: CapabilityState,
    observedAt: EngineInstant,
    topologySignature: TopologySignature,
    source: CapabilitySource,
    confidence: CapabilityConfidence,
    failure: ControlFailure? = nil
  ) {
    self.method = method
    self.state = state
    self.observedAt = observedAt
    self.topologySignature = topologySignature
    self.source = source
    self.confidence = confidence
    self.failure = failure
  }
}
