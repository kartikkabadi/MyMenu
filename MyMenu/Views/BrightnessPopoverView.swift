import SwiftUI

/// Brightness panel — `PopoverView` + `DimmingView` parity with One Menu Liquid Glass.
struct BrightnessPopoverView: View {
  @Bindable var router: DisplayRouter
  var animationToken: PopoverAnimationToken

  var body: some View {
    Group {
      if #available(macOS 26.0, *) {
        tahoePanel
      } else {
        legacyPanel
      }
    }
  }

  @available(macOS 26.0, *)
  private var tahoePanel: some View {
    VStack(alignment: .leading, spacing: BrightnessDesign.sectionSpacing) {
      glassContentBlock

      Button {
        AppDelegate.shared?.quitApp()
      } label: {
        Text("Quit")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(BrightnessDesign.quitLabelColor)
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.glassProminent)
      .tint(BrightnessDesign.quitTint)
      .controlSize(.regular)
      .contentShape(Capsule())
    }
    .padding(BrightnessDesign.panelPadding)
    .frame(width: BrightnessDesign.panelWidth)
  }

  @available(macOS 26.0, *)
  private var glassContentBlock: some View {
    VStack(alignment: .leading, spacing: BrightnessDesign.sectionSpacing) {
      Text("External Monitor Brightness")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.primary)

      if router.presentationDisplays.isEmpty {
        Text("Connect an external display.")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      } else if let display = router.presentationDisplays.first {
        GlassBrightnessControl(displayID: display.id, router: router)

        Text(display.tierLabel)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.tertiary)
      }
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 2)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      RoundedRectangle(cornerRadius: BrightnessDesign.panelCornerRadius, style: .continuous)
        .glassEffect(.regular.interactive())
    }
  }

  private var legacyPanel: some View {
    VStack(spacing: BrightnessDesign.sectionSpacing) {
      Text("External Monitor Brightness")
        .font(.system(size: 13, weight: .semibold))

      if let display = router.presentationDisplays.first {
        ExternalBrightnessSlider(displayID: display.id, router: router)
        Text(display.tierLabel)
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
      }

      Button("Quit") {
        AppDelegate.shared?.quitApp()
      }
      .buttonStyle(.borderedProminent)
      .tint(BrightnessDesign.quitTint)
    }
    .padding(BrightnessDesign.panelPadding)
    .frame(width: BrightnessDesign.panelWidth)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BrightnessDesign.panelCornerRadius))
  }
}
