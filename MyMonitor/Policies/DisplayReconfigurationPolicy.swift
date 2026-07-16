import Foundation

/// Pure policy used when an asynchronous display probe is installed.
///
/// Values may change while hardware discovery is running. Installation therefore prefers the
/// current in-memory value over persisted or probed snapshots, then clamps against the latest
/// configured range.
enum DisplayReconfigurationPolicy {
  static func resolvedBrightness(
    live: Double?,
    persisted: Double?,
    probed: Double?,
    allowedRange: ClosedRange<Double>
  ) -> Double {
    let lower = min(max(allowedRange.lowerBound, 0), 1)
    let upper = min(max(allowedRange.upperBound, 0), 1)
    let normalizedRange = min(lower, upper)...max(lower, upper)
    let candidate = live ?? persisted ?? probed ?? 1
    return min(max(candidate, normalizedRange.lowerBound), normalizedRange.upperBound)
  }

  static func removedIDs<ID: Hashable>(
    installed: Set<ID>,
    online: Set<ID>
  ) -> Set<ID> {
    installed.subtracting(online)
  }
}
