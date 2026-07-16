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
      ForEach(store.monitors) { monitor in
        MonitorBrightnessRow(monitor: monitor, store: store)

        if monitor.id != store.monitors.last?.id {
          Divider()
            .padding(.horizontal, 14)
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
  let monitor: MonitorPresentation
  @Bindable var store: DisplayPresentationStore

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(monitor.name)
          .font(.body.weight(.medium))
          .lineLimit(1)
          .truncationMode(.middle)
          .help(monitor.name)

        Spacer(minLength: 8)

        if let brightness = monitor.brightness {
          Text(brightness, format: .percent.precision(.fractionLength(0)))
            .font(.callout)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
      }

      if monitor.brightness != nil {
        BrightnessSlider(monitor: monitor, store: store)
      }

      Text(monitor.control.label)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }
}
