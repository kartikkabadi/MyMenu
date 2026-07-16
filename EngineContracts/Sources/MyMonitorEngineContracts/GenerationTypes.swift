import Foundation

struct EngineGeneration: RawRepresentable, Hashable, Comparable, Codable, Sendable {
  let rawValue: UInt64

  init(rawValue: UInt64) {
    self.rawValue = rawValue
  }

  static let zero = EngineGeneration(rawValue: 0)

  static func < (lhs: EngineGeneration, rhs: EngineGeneration) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  func next() -> EngineGeneration {
    EngineGeneration(rawValue: rawValue &+ 1)
  }
}

struct SessionGeneration: RawRepresentable, Hashable, Comparable, Codable, Sendable {
  let rawValue: UInt64

  init(rawValue: UInt64) {
    self.rawValue = rawValue
  }

  static let zero = SessionGeneration(rawValue: 0)

  static func < (lhs: SessionGeneration, rhs: SessionGeneration) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  func next() -> SessionGeneration {
    SessionGeneration(rawValue: rawValue &+ 1)
  }
}
