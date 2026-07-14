import SwiftUI

/// One Menu `AppearModifier`: opacity + scale + blur on every popover open.
struct PopoverAppearModifier: ViewModifier {
  @Bindable var token: PopoverAnimationToken
  @State private var appeared = false

  func body(content: Content) -> some View {
    content
      .opacity(appeared ? 1 : 0)
      .scaleEffect(appeared ? 1 : BrightnessDesign.appearScale, anchor: .top)
      .blur(radius: appeared ? 0 : BrightnessDesign.appearBlur)
      .onAppear {
        playAppear()
      }
      .onChange(of: token.appearGeneration) { _, _ in
        playAppear()
      }
  }

  private func playAppear() {
    appeared = false
    withAnimation(BrightnessDesign.appearSpring) {
      appeared = true
    }
  }
}

extension View {
  func popoverAppear(token: PopoverAnimationToken) -> some View {
    modifier(PopoverAppearModifier(token: token))
  }
}
