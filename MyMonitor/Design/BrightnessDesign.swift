import SwiftUI

enum BrightnessDesign {
  /// Compact enough to feel like a system control, large enough for several displays.
  static let panelWidth: CGFloat = 320
  static let panelHeight: CGFloat = 280

  // Retained while the old experimental surfaces are removed in the next cleanup pass.
  static let panelCornerRadius: CGFloat = 20
  static let panelPadding: CGFloat = 16
  static let onboardingHeight: CGFloat = 560
  static let sectionSpacing: CGFloat = 10

  static let appearSpring = Animation.spring(response: 0.36, dampingFraction: 0.86)
  static let appearScale: CGFloat = 0.96
  static let appearBlur: CGFloat = 6

  static let accent = Color.accentColor
  static let panelBackground = Color.clear
  static let quitTint = Color.accentColor
  static let quitLabelColor = Color.primary

  // Legacy custom slider values used by the compatibility view.
  static let iconSize: CGFloat = 15
  static let iconMuted = Color.primary.opacity(0.45)
  static let trackHeight: CGFloat = 4
  static let trackBackground = Color.primary.opacity(0.12)
  static let trackFill = Color.accentColor
  static let knobDiameter: CGFloat = 22
  static let knobFill = Color.white
  static let knobShadow = Color.black.opacity(0.22)
  static let sliderRowHeight: CGFloat = 32
}
