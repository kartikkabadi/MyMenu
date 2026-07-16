import SwiftUI

enum BrightnessDesign {
  /// Narrow enough to read as a system control while preserving native slider precision.
  static let popoverWidth: CGFloat = 312

  /// Keeps unusually large display sets inside a compact menu-bar surface.
  static let maximumMonitorListHeight: CGFloat = 360

  /// Hard safety bound for the AppKit host; normal content should size below this naturally.
  static let maximumPopoverHeight: CGFloat = 440

  /// Temporary shell rule until F6 replaces count-based overflow with the final layout.
  static let maximumUnscrolledMonitorCount = 4
}
