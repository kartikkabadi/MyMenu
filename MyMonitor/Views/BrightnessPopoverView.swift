import SwiftUI

/// The complete product surface: connected external monitors and their brightness.
struct BrightnessPopoverView: View {
  @Bindable var store: DisplayPresentationStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(spacing: 0) {
      content

      Divider()

      footer
    }
    .frame(width: BrightnessDesign.popoverWidth)
    .fixedSize(horizontal: false, vertical: true)
    .animation(
      reduceMotion ? nil : .easeInOut(duration: 0.18),
      value: store.monitors.map(\.id)
    )
  }

  @ViewBuilder
  private var content: some View {
    switch store.state {
    case .detecting(let cached):
      if cached.isEmpty {
        detectingState
      } else {
        VStack(spacing: 0) {
          detectingBanner
          Divider()
          monitorList
        }
      }

    case .ready(let monitors):
      if monitors.isEmpty {
        emptyState
      } else {
        monitorList
      }

    case .empty:
      emptyState

    case .failed(let failure):
      failedState(failure)
    }
  }

  private var detectingState: some View {
    HStack(spacing: 9) {
      ProgressView()
        .controlSize(.small)

      Text("Detecting displays…")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 24)
    .padding(.vertical, 28)
  }

  private var detectingBanner: some View {
    HStack(spacing: 7) {
      ProgressView()
        .controlSize(.mini)

      Text("Checking displays…")
        .font(.caption)
        .foregroundStyle(.secondary)

      Spacer()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
  }

  private var monitorList: some View {
    VStack(spacing: 0) {
      if store.monitors.count > 1 {
        displaysHeading
      }

      if store.monitors.count >= BrightnessDesign.scrollingMonitorThreshold {
        ScrollView {
          monitorRows
        }
        .scrollIndicators(.automatic)
        .frame(height: BrightnessDesign.maximumMonitorListHeight)
      } else {
        monitorRows
      }
    }
  }

  private var displaysHeading: some View {
    HStack {
      Text("Displays")
        .font(.callout.weight(.semibold))

      Spacer()
    }
    .padding(.horizontal, 14)
    .padding(.top, 12)
    .padding(.bottom, 4)
  }

  private var monitorRows: some View {
    VStack(spacing: 0) {
      ForEach(store.monitors) { monitor in
        MonitorBrightnessRow(monitor: monitor, store: store)
          .transition(
            reduceMotion
              ? .identity
              : .opacity.combined(with: .move(edge: .top))
          )

        if monitor.id != store.monitors.last?.id {
          Divider()
            .padding(.horizontal, 14)
        }
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 10) {
      Image(systemName: "display")
        .font(.system(size: 30, weight: .regular))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text("No external displays")
        .font(.headline)

      Text("Connect a display and MyMonitor will detect it.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      Button("Refresh") {
        store.refresh()
      }
      .controlSize(.small)
      .padding(.top, 2)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 24)
    .padding(.vertical, 26)
  }

  private func failedState(_ failure: DisplayPresentationFailure) -> some View {
    VStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 28, weight: .regular))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text("Unable to detect displays")
        .font(.headline)

      Text(failure.message)
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)

      if failure.canRetry {
        Button("Retry") {
          store.refresh()
        }
        .controlSize(.small)
        .padding(.top, 2)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 24)
    .padding(.vertical, 26)
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

      controlStatus
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }

  @ViewBuilder
  private var controlStatus: some View {
    switch monitor.control {
    case .checking:
      HStack(spacing: 6) {
        ProgressView()
          .controlSize(.mini)

        Text(monitor.control.label)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

    case .available(let method):
      HStack(spacing: 5) {
        Text(method.label)
          .font(.caption)
          .foregroundStyle(.secondary)

        if method != .hardware {
          ControlMethodDisclosureButton(
            monitorName: monitor.name,
            method: method
          )
        }
      }

    case .unavailable(let message, let canRetry):
      VStack(alignment: .leading, spacing: 6) {
        Text("Brightness unavailable")
          .font(.caption)
          .foregroundStyle(.red)

        Text(message)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        if canRetry {
          Button("Retry") {
            store.retryControl(for: monitor.id)
          }
          .controlSize(.small)
        }
      }
    }
  }
}

private struct ControlMethodDisclosureButton: View {
  let monitorName: String
  let method: MonitorControlMethod

  @State private var isPresented = false

  var body: some View {
    Button {
      isPresented.toggle()
    } label: {
      Image(systemName: "info.circle")
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .help("About \(method.label.lowercased())")
    .accessibilityLabel("About control method for \(monitorName)")
    .popover(isPresented: $isPresented, arrowEdge: .trailing) {
      VStack(alignment: .leading, spacing: 6) {
        Text(method.label)
          .font(.headline)

        Text(method.explanation)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(14)
      .frame(width: 260, alignment: .leading)
    }
  }
}

private extension MonitorControlMethod {
  var explanation: String {
    switch self {
    case .hardware:
      "MyMonitor is changing the monitor’s physical backlight."
    case .software:
      "MyMonitor is adjusting this display with a software brightness curve because hardware control is unavailable."
    case .shade:
      "MyMonitor is using a display shade. The monitor’s physical backlight is unchanged."
    }
  }
}
