import Foundation

public struct EngineInstant: RawRepresentable, Hashable, Comparable, Codable, Sendable {
  public let rawValue: Int64

  public init(rawValue: Int64) {
    self.rawValue = rawValue
  }

  public static let zero = EngineInstant(rawValue: 0)

  public static func < (lhs: EngineInstant, rhs: EngineInstant) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public func advanced(by duration: Duration) -> EngineInstant {
    let delta = duration.nanosecondsClampedToInt64
    let (value, overflow) = rawValue.addingReportingOverflow(delta)
    return EngineInstant(rawValue: overflow ? (delta >= 0 ? .max : .min) : value)
  }

  public func duration(to other: EngineInstant) -> Duration {
    let (delta, overflow) = other.rawValue.subtractingReportingOverflow(rawValue)
    return .nanoseconds(overflow ? (other.rawValue >= rawValue ? Int64.max : Int64.min) : delta)
  }
}

public protocol EngineClock: Sendable {
  func now() async -> EngineInstant
  func sleep(until deadline: EngineInstant) async throws
}

private extension Duration {
  var nanosecondsClampedToInt64: Int64 {
    let components = self.components
    let seconds = components.seconds
    let attoseconds = components.attoseconds

    let (secondsNanoseconds, secondsOverflow) = seconds.multipliedReportingOverflow(by: 1_000_000_000)
    let fractionalNanoseconds = attoseconds / 1_000_000_000
    let (combined, combinedOverflow) = secondsNanoseconds.addingReportingOverflow(fractionalNanoseconds)

    if secondsOverflow || combinedOverflow {
      return seconds >= 0 ? .max : .min
    }
    return combined
  }
}
