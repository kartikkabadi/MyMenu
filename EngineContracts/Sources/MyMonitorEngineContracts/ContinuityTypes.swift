import Foundation

public struct ContinuityID: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: UUID

  public init(rawValue: UUID = UUID()) {
    self.rawValue = rawValue
  }
}

public struct ContinuityEpoch: RawRepresentable, Hashable, Comparable, Codable, Sendable {
  public let rawValue: UInt64

  public init(rawValue: UInt64) {
    self.rawValue = rawValue
  }

  public static let zero = ContinuityEpoch(rawValue: 0)

  public static func < (lhs: ContinuityEpoch, rhs: ContinuityEpoch) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public func next() -> ContinuityEpoch {
    ContinuityEpoch(rawValue: rawValue &+ 1)
  }
}

public struct TopologySignature: RawRepresentable, Hashable, Codable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}
