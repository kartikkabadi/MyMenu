import SwiftUI

@available(macOS 26.0, *)
struct GlassBrightnessControl: View {
  let displayID: CGDirectDisplayID
  @Bindable var router: DisplayRouter

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "moon.fill")
        .font(.system(size: 14, weight: .medium))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.secondary)
        .frame(width: 22)

      Slider(
        value: sliderBinding(persistWhileDragging: false),
        in: 0...1,
        onEditingChanged: { editing in
          if !editing, let value = router.displays.first(where: { $0.id == displayID })?.brightness {
            router.setBrightness(value, for: displayID, animated: true, persist: true)
          }
        }
      ) {
        Text("Brightness")
      }
      .controlSize(.large)

      Image(systemName: "sun.max.fill")
        .font(.system(size: 14, weight: .medium))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.secondary)
        .frame(width: 22)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  private func sliderBinding(persistWhileDragging: Bool) -> Binding<Double> {
    Binding(
      get: {
        router.displays.first(where: { $0.id == displayID })?.brightness ?? 0
      },
      set: { newValue in
        router.setBrightness(
          newValue,
          for: displayID,
          animated: false,
          persist: persistWhileDragging
        )
      }
    )
  }
}
