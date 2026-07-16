public struct EngineGeneration: RawRepresentable, Hashable, Comparable, Codable, Sendable {
  public let rawValue: UInt64

  public init(rawValue: UInt64) {
    self.rawValue = rawValue
  }

  public static let zero = EngineGeneration(rawValue: 0)

  public static func < (lhs: EngineGeneration, rhs: EngineGeneration) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public func next() -> EngineGeneration {
    EngineGeneration(rawValue: rawValue &+ 1)
  }
}

public struct SessionGeneration: RawRepresentable, Hashable, Comparable, Codable, Sendable {
  public let rawValue: UInt64

  public init(rawValue: UInt64) {
    self.rawValue = rawValue
  }

  public static let zero = SessionGeneration(rawValue: 0)

  public static func < (lhs: SessionGeneration, rhs: SessionGeneration) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public func next() -> SessionGeneration {
    SessionGeneration(rawValue: rawValue &+ 1)
  }
}
