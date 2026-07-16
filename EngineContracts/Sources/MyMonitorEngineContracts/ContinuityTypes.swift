import Foundation

struct ContinuityToken: RawRepresentable, Hashable, Codable, Sendable {
  let rawValue: UUID

  init(rawValue: UUID = UUID()) {
    self.rawValue = rawValue
  }
}

struct ContinuityEpoch: RawRepresentable, Hashable, Comparable, Codable, Sendable {
  let rawValue: UInt64

  init(rawValue: UInt64) {
    self.rawValue = rawValue
  }

  static let zero = ContinuityEpoch(rawValue: 0)

  static func < (lhs: ContinuityEpoch, rhs: ContinuityEpoch) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  func next() -> ContinuityEpoch {
    ContinuityEpoch(rawValue: rawValue &+ 1)
  }
}

struct TopologySignature: RawRepresentable, Hashable, Codable, Sendable {
  let rawValue: String

  init(rawValue: String) {
    self.rawValue = rawValue
  }
}
