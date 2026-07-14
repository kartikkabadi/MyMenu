import SwiftUI

/// Three short, keyboard-friendly pages shown once after installation.
struct OnboardingView: View {
  private struct Page {
    let symbol: String
    let eyebrow: String
    let title: String
    let body: String
  }

  private let pages = [
    Page(
      symbol: "sun.max.fill",
      eyebrow: "A quieter menu bar",
      title: "Make every display feel right.",
      body: "MyMonitor controls external-display brightness with the best available path, from hardware DDC to a dependable software fallback."
    ),
    Page(
      symbol: "macwindow.on.rectangle",
      eyebrow: "Optional window tools",
      title: "Move faster, when you want to.",
      body: "Window snapping and Option–Tab are opt-in. MyMonitor only asks for Accessibility or Screen Recording when you turn those tools on."
    ),
    Page(
      symbol: "checkmark.seal.fill",
      eyebrow: "You are in control",
      title: "Ready when you are.",
      body: "Use the status-bar sun to open MyMonitor. You can change these choices any time, and your display preferences stay on this Mac."
    )
  ]

  @State private var pageIndex = 0
  @FocusState private var isFocused: Bool

  let onComplete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("MYMONITOR")
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .tracking(1.4)
          .foregroundStyle(.secondary)
        Spacer()
        Text("\(pageIndex + 1) / \(pages.count)")
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(.tertiary)
      }

      Spacer(minLength: 18)

      VStack(alignment: .leading, spacing: 16) {
        Image(systemName: pages[pageIndex].symbol)
          .font(.system(size: 25, weight: .semibold))
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(BrightnessDesign.accent)
          .frame(width: 58, height: 58)
          .background(BrightnessDesign.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 17, style: .continuous))

        VStack(alignment: .leading, spacing: 8) {
          Text(pages[pageIndex].eyebrow)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(BrightnessDesign.accent)
          Text(pages[pageIndex].title)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .tracking(-0.7)
            .fixedSize(horizontal: false, vertical: true)
          Text(pages[pageIndex].body)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      Spacer(minLength: 18)

      HStack(spacing: 6) {
        ForEach(pages.indices, id: \.self) { index in
          Capsule()
            .fill(index == pageIndex ? BrightnessDesign.accent : Color.white.opacity(0.18))
            .frame(width: index == pageIndex ? 18 : 6, height: 6)
        }
        Spacer()
        Text("Use ← → to browse")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.tertiary)
      }

      HStack(spacing: 8) {
        if pageIndex > 0 {
          Button("Back") { move(by: -1) }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .frame(width: 62, height: 36)
        }

        Spacer()

        Button(pageIndex == pages.count - 1 ? "Start using MyMonitor" : "Next") {
          if pageIndex == pages.count - 1 {
            onComplete()
          } else {
            move(by: 1)
          }
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(BrightnessDesign.accent, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
      }
      .padding(.top, 12)
    }
    .padding(28)
    .frame(width: BrightnessDesign.panelWidth, height: BrightnessDesign.onboardingHeight)
    .background(BrightnessDesign.panelBackground)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
    }
    .focusable(true)
    .focused($isFocused)
    .onMoveCommand { direction in
      switch direction {
      case .left: move(by: -1)
      case .right: move(by: 1)
      default: break
      }
    }
    .onAppear { isFocused = true }
  }

  private func move(by amount: Int) {
    pageIndex = min(max(pageIndex + amount, 0), pages.count - 1)
  }
}
