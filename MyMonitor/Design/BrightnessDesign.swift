import SwiftUI

enum BrightnessDesign {
  static let panelWidth: CGFloat = 338
  static let panelCornerRadius: CGFloat = 24
  static let panelPadding: CGFloat = 18
  static let panelHeight: CGFloat = 448
  static let onboardingHeight: CGFloat = 600
  static let sectionSpacing: CGFloat = 12

  static let appearSpring = Animation.spring(response: 0.44, dampingFraction: 0.82)
  static let appearScale: CGFloat = 0.92
  static let appearBlur: CGFloat = 10

  static let accent = Color(red: 0.23, green: 0.52, blue: 1.0)
  static let panelBackground = Color(red: 0.055, green: 0.06, blue: 0.09)
  static let quitTint = Color(red: 0.23, green: 0.52, blue: 1.0)
  static let quitLabelColor = Color.white

  // Legacy custom slider (pre–macOS 26)
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
