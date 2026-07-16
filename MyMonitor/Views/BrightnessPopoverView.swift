import SwiftUI

/// The complete product surface: connected external monitors and their brightness.
struct BrightnessPopoverView: View {
  @Bindable var router: DisplayRouter

  var body: some View {
    VStack(spacing: 0) {
      header

      Divider()
        .opacity(0.35)

      if router.presentationDisplays.isEmpty {
        emptyState
      } else {
        monitorList
      }

      Divider()
        .opacity(0.35)

      footer
    }
    .frame(
      width: BrightnessDesign.panelWidth,
      height: BrightnessDesign.panelHeight
    )
    .background(.regularMaterial)
  }

  private var header: some View {
    HStack(spacing: 10) {
      Image(systemName: "display.2")
        .font(.system(size: 15, weight: .semibold))
        .symbolRenderingMode(.hierarchical)
        .frame(width: 24, height: 24)

      VStack(alignment: .leading, spacing: 1) {
        Text("MyMonitor")
          .font(.system(size: 13, weight: .semibold))
        Text("External display brightness")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 12)

      Button {
        router.reconfigure()
      } label: {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 11, weight: .semibold))
          .frame(width: 24, height: 24)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
      .help("Refresh displays")
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }

  private var monitorList: some View {
    ScrollView {
      VStack(spacing: 0) {
        ForEach(router.presentationDisplays) { display in
          MonitorBrightnessRow(display: display, router: router)

          if display.id != router.presentationDisplays.last?.id {
            Divider()
              .opacity(0.2)
              .padding(.leading, 46)
          }
        }
      }
    }
    .scrollIndicators(.never)
  }

  private var emptyState: some View {
    VStack(spacing: 10) {
      Image(systemName: "display.trianglebadge.exclamationmark")
        .font(.system(size: 30, weight: .regular))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.secondary)

      Text("No external display")
        .font(.system(size: 13, weight: .semibold))

      Text("Connect a monitor, then refresh.")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(24)
  }

  private var footer: some View {
    HStack {
      let count = router.presentationDisplays.count
      Text(count == 1 ? "1 monitor" : "\(count) monitors")
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)

      Spacer()

      Button("Quit") {
        AppDelegate.shared?.quitApp()
      }
      .buttonStyle(.plain)
      .font(.system(size: 10, weight: .semibold))
      .foregroundStyle(.secondary)
      .keyboardShortcut("q", modifiers: [.command])
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
  }
}

private struct MonitorBrightnessRow: View {
  let display: ExternalDisplayItem
  @Bindable var router: DisplayRouter

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 9) {
        Image(systemName: "display")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
          .frame(width: 22)

        VStack(alignment: .leading, spacing: 1) {
          Text(display.name)
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)

          Text(display.tierLabel)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.tertiary)
        }

        Spacer(minLength: 8)

        Text("\(Int((display.brightness * 100).rounded()))%")
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }

      GlassBrightnessControl(displayID: display.id, router: router)
        .padding(.horizontal, -4)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }
}
