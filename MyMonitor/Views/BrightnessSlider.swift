import SwiftUI

/// Native brightness control for one external display.
struct BrightnessSlider: View {
  let monitor: MonitorPresentation
  @Bindable var store: DisplayPresentationStore

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "moon")
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Slider(
        value: brightnessBinding,
        in: monitor.allowedRange,
        onEditingChanged: handleEditingChange
      )
      .controlSize(.regular)
      .accessibilityLabel("Brightness for \(monitor.name)")
      .accessibilityValue("\(percentage) percent")
      .accessibilityHint("Adjusts external-display brightness.")

      Image(systemName: "sun.max")
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
  }

  private var percentage: Int {
    Int(((monitor.brightness ?? monitor.allowedRange.lowerBound) * 100).rounded())
  }

  private var brightnessBinding: Binding<Double> {
    Binding(
      get: {
        store.monitor(withID: monitor.id)?.brightness
          ?? monitor.allowedRange.lowerBound
      },
      set: { value in
        store.updateBrightness(value, for: monitor.id)
      }
    )
  }

  private func handleEditingChange(_ isEditing: Bool) {
    if isEditing {
      store.beginBrightnessAdjustment(for: monitor.id)
    } else {
      store.endBrightnessAdjustment(for: monitor.id)
    }
  }
}
