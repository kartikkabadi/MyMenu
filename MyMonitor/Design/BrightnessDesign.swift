import SwiftUI

enum BrightnessDesign {
  /// Narrow enough to read as a system control while preserving native slider precision.
  static let popoverWidth: CGFloat = 312

  /// Keeps the display heading and footer stationary for larger monitor sets.
  static let maximumMonitorListHeight: CGFloat = 340

  /// Hard safety bound for the AppKit host; normal content should size below this naturally.
  static let maximumPopoverHeight: CGFloat = 440

  /// Four or more displays use a native scrolling list.
  static let scrollingMonitorThreshold = 4
}
