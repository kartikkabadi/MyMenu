import SwiftUI

@available(macOS 26.0, *)
struct GlassBrightnessControl: View {
  let monitorID: MonitorID
  @Bindable var store: DisplayPresentationStore

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "moon.fill")
        .font(.system(size: 14, weight: .medium))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.secondary)
        .frame(width: 22)

      Slider(
        value: sliderBinding,
        in: store.monitor(withID: monitorID)?.allowedRange ?? 0...1,
        onEditingChanged: { editing in
          if editing {
            store.beginBrightnessAdjustment(for: monitorID)
          } else {
            store.endBrightnessAdjustment(for: monitorID)
          }
        }
      ) {
        Text("Brightness")
      }
      .controlSize(.regular)

      Image(systemName: "sun.max.fill")
        .font(.system(size: 14, weight: .medium))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.secondary)
        .frame(width: 22)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  private var sliderBinding: Binding<Double> {
    Binding(
      get: {
        store.monitor(withID: monitorID)?.brightness ?? 0
      },
      set: { newValue in
        store.updateBrightness(newValue, for: monitorID)
      }
    )
  }
}
