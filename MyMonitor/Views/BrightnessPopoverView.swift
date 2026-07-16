import SwiftUI

/// The complete product surface: connected external monitors and their brightness.
struct BrightnessPopoverView: View {
  @Bindable var store: DisplayPresentationStore

  var body: some View {
    VStack(spacing: 0) {
      content

      Divider()

      footer
    }
    .frame(width: BrightnessDesign.popoverWidth)
    .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  private var content: some View {
    if store.monitors.isEmpty {
      emptyState
    } else {
      monitorList
    }
  }

  @ViewBuilder
  private var monitorList: some View {
    if store.monitors.count <= BrightnessDesign.maximumUnscrolledMonitorCount {
      monitorRows
    } else {
      ScrollView {
        monitorRows
      }
      .frame(height: BrightnessDesign.maximumMonitorListHeight)
    }
  }

  private var monitorRows: some View {
    VStack(spacing: 0) {
      ForEach(store.monitors) { display in
        MonitorBrightnessRow(display: display, store: store)

        if display.id != store.monitors.last?.id {
          Divider()
            .opacity(0.2)
            .padding(.leading, 46)
        }
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 10) {
      Image(systemName: "display.trianglebadge.exclamationmark")
        .font(.system(size: 30, weight: .regular))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text("No external display")
        .font(.headline)

      Text("Connect a monitor and MyMonitor will detect it.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 24)
    .padding(.vertical, 28)
  }

  private var footer: some View {
    HStack {
      Spacer()

      Button("Quit") {
        AppDelegate.shared?.quitApp()
      }
      .keyboardShortcut("q", modifiers: [.command])
      .controlSize(.small)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
  }
}

private struct MonitorBrightnessRow: View {
  let display: MonitorPresentation
  @Bindable var store: DisplayPresentationStore

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

          Text(display.control.label)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.tertiary)
        }

        Spacer(minLength: 8)

        if let brightness = display.brightness {
          Text("\(Int((brightness * 100).rounded()))%")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
      }

      GlassBrightnessControl(monitorID: display.id, store: store)
        .padding(.horizontal, -4)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }
}
