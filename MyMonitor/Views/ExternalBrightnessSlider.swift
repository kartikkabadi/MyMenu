import SwiftUI

/// One Menu–style brightness track: thin blue fill, round thumb, light moon/sun icons.
struct ExternalBrightnessSlider: View {
  let displayID: CGDirectDisplayID
  @Bindable var router: DisplayRouter

  @GestureState private var isDragging = false

  private var value: Double {
    router.displays.first(where: { $0.id == displayID })?.brightness ?? 0
  }

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "moon")
        .font(.system(size: BrightnessDesign.iconSize, weight: .light))
        .foregroundStyle(BrightnessDesign.iconMuted)
        .frame(width: 18)

      GeometryReader { geo in
        let width = geo.size.width
        let travel = max(width - BrightnessDesign.knobDiameter, 1)
        let knobX = CGFloat(value) * travel

        ZStack(alignment: .leading) {
          Capsule()
            .fill(BrightnessDesign.trackBackground)
            .frame(height: BrightnessDesign.trackHeight)

          Capsule()
            .fill(BrightnessDesign.trackFill)
            .frame(
              width: max(BrightnessDesign.knobDiameter * 0.35, knobX + BrightnessDesign.knobDiameter * 0.45),
              height: BrightnessDesign.trackHeight
            )

          Circle()
            .fill(BrightnessDesign.knobFill)
            .shadow(color: BrightnessDesign.knobShadow, radius: 5, y: 1)
            .frame(width: BrightnessDesign.knobDiameter, height: BrightnessDesign.knobDiameter)
            .overlay {
              Circle()
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
            }
            .offset(x: knobX)
            .scaleEffect(isDragging ? 1.08 : 1)
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .contentShape(Rectangle())
        .gesture(dragGesture(travel: travel))
      }
      .frame(height: BrightnessDesign.sliderRowHeight)

      Image(systemName: "sun.max")
        .font(.system(size: BrightnessDesign.iconSize, weight: .light))
        .foregroundStyle(BrightnessDesign.iconMuted)
        .frame(width: 18)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("External monitor brightness")
    .accessibilityValue("\(Int((1 - value) * 100)) percent brightness")
  }

  private func dragGesture(travel: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .updating($isDragging) { _, state, _ in state = true }
      .onChanged { gesture in
        let x = min(max(gesture.location.x - BrightnessDesign.knobDiameter / 2, 0), travel)
        let newValue = Double(x / travel)
        router.setBrightness(
          newValue,
          for: displayID,
          animated: false,
          persist: false
        )
      }
      .onEnded { gesture in
        let x = min(max(gesture.location.x - BrightnessDesign.knobDiameter / 2, 0), travel)
        let newValue = Double(x / travel)
        router.setBrightness(
          newValue,
          for: displayID,
          animated: true,
          persist: true
        )
      }
  }
}
