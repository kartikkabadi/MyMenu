import Foundation
import Observation

/// Drives Recreate + appear animation on every `NSPopover` show (One Menu pattern).
@MainActor
@Observable
final class PopoverAnimationToken {
  private(set) var contentGeneration = UUID()
  private(set) var appearGeneration = 0

  func prepareForShow() {
    contentGeneration = UUID()
    appearGeneration += 1
  }
}
