import Foundation

/// Pure policies used while asynchronous display discovery is reconciled with live UI state.
enum DisplayReconfigurationPolicy {
  /// Installation prefers the current in-memory value over persisted or probed snapshots, then
  /// clamps against the latest configured range.
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

  /// Collapse only a fully mirrored topology. Partial mirroring must retain unrelated extended
  /// displays instead of hiding them from the popover.
  static func presentationIDs<ID: Hashable>(
    connected: [ID],
    mirrored: Set<ID>,
    isFullMirror: Bool
  ) -> [ID] {
    guard isFullMirror,
      let representative = connected.first(where: mirrored.contains)
    else {
      return connected
    }
    return [representative]
  }
}
