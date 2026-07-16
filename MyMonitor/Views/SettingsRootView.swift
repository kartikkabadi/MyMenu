import AppKit
import SwiftUI

struct SettingsRootView: View {
  @Bindable var store: DisplayPresentationStore
  @Bindable var launchAtLoginController: LaunchAtLoginController
  @State private var selection: SettingsDestination = .general

  var body: some View {
    NavigationSplitView {
      List(SettingsDestination.allCases, selection: $selection) { destination in
        Label(destination.title, systemImage: destination.symbol)
          .tag(destination)
      }
      .listStyle(.sidebar)
      .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 230)
    } detail: {
      detail
        .navigationTitle(selection.title)
    }
    .frame(minWidth: 620, minHeight: 420)
  }

  @ViewBuilder
  private var detail: some View {
    switch selection {
    case .general:
      GeneralSettingsView(
        launchAtLoginController: launchAtLoginController
      )
    case .displays:
      DisplaysSettingsSummaryView(store: store)
    case .advanced:
      AdvancedSettingsView(store: store)
    case .about:
      AboutSettingsView()
    }
  }
}

private enum SettingsDestination: String, CaseIterable, Identifiable {
  case general
  case displays
  case advanced
  case about

  var id: Self { self }

  var title: String {
    switch self {
    case .general: "General"
    case .displays: "Displays"
    case .advanced: "Advanced"
    case .about: "About"
    }
  }

  var symbol: String {
    switch self {
    case .general: "gearshape"
    case .displays: "display.2"
    case .advanced: "wrench.and.screwdriver"
    case .about: "info.circle"
    }
  }
}

private struct GeneralSettingsView: View {
  @Bindable var launchAtLoginController: LaunchAtLoginController

  var body: some View {
    Form {
      Section("Startup") {
        Toggle(
          "Launch MyMonitor at login",
          isOn: Binding(
            get: { launchAtLoginController.isRequested },
            set: { launchAtLoginController.setRequested($0) }
          )
        )
        .disabled(!launchAtLoginController.canChange)

        if let statusMessage {
          Text(statusMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if let errorMessage = launchAtLoginController.errorMessage {
          Text(errorMessage)
            .font(.caption)
            .foregroundStyle(.red)
        }
      }

      Section("App") {
        LabeledContent("Location", value: "Menu bar")
        LabeledContent("Data", value: "Stored locally")
      }

      Section {
        Text("Use the MyMonitor menu-bar icon to adjust each connected external display.")
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }

  private var statusMessage: String? {
    switch launchAtLoginController.status {
    case .requiresApproval:
      "Approval is required in System Settings › General › Login Items."
    case .unavailable:
      "Launch at login is unavailable for this build."
    case .notRegistered, .enabled:
      nil
    }
  }
}

private struct DisplaysSettingsSummaryView: View {
  @Bindable var store: DisplayPresentationStore

  var body: some View {
    Group {
      if case .failed(let failure) = store.state {
        ContentUnavailableView(
          "Unable to Detect Displays",
          systemImage: "exclamationmark.triangle",
          description: Text(failure.message)
        )
      } else if store.monitors.isEmpty {
        ContentUnavailableView(
          "No External Displays",
          systemImage: "display",
          description: Text("Connect a display and MyMonitor will detect it.")
        )
      } else {
        Form {
          Section("Connected Displays") {
            ForEach(store.monitors) { monitor in
              LabeledContent {
                VStack(alignment: .trailing, spacing: 2) {
                  if let brightness = monitor.brightness {
                    Text(brightness, format: .percent.precision(.fractionLength(0)))
                      .monospacedDigit()
                  }

                  Text(monitor.control.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              } label: {
                Text(monitor.name)
                  .lineLimit(1)
                  .truncationMode(.middle)
              }
            }
          }

          if store.state.isDetecting {
            Section {
              HStack(spacing: 8) {
                ProgressView()
                  .controlSize(.small)
                Text("Checking displays…")
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
        .formStyle(.grouped)
      }
    }
  }
}

private struct AdvancedSettingsView: View {
  @Bindable var store: DisplayPresentationStore

  var body: some View {
    Form {
      Section("Detection") {
        Button("Re-detect Displays") {
          store.refresh()
        }

        if store.state.isDetecting {
          HStack(spacing: 8) {
            ProgressView()
              .controlSize(.small)
            Text("Checking connected displays…")
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .formStyle(.grouped)
  }
}

private struct AboutSettingsView: View {
  var body: some View {
    VStack(spacing: 10) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .scaledToFit()
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)

      Text("MyMonitor")
        .font(.title2.weight(.semibold))

      Text(versionText)
        .foregroundStyle(.secondary)

      Text("External-monitor brightness control for macOS.")
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(32)
  }

  private var versionText: String {
    let version = Bundle.main.object(
      forInfoDictionaryKey: "CFBundleShortVersionString"
    ) as? String ?? "Development"
    let build = Bundle.main.object(
      forInfoDictionaryKey: "CFBundleVersion"
    ) as? String ?? ""

    guard !build.isEmpty else { return "Version \(version)" }
    return "Version \(version) (\(build))"
  }
}
