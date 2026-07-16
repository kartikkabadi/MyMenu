import AppKit
import SwiftUI

struct SettingsRootView: View {
  @Bindable var store: DisplayPresentationStore
  @Bindable var configurationStore: DisplayConfigurationStore
  @Bindable var launchAtLoginController: LaunchAtLoginController
  @Bindable var keyboardShortcutController: KeyboardShortcutController
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
      DisplaysSettingsView(
        store: store,
        configurationStore: configurationStore
      )
    case .keyboard:
      KeyboardSettingsView(
        configurationStore: configurationStore,
        keyboardShortcutController: keyboardShortcutController
      )
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
  case keyboard
  case advanced
  case about

  var id: Self { self }

  var title: String {
    switch self {
    case .general: "General"
    case .displays: "Displays"
    case .keyboard: "Keyboard"
    case .advanced: "Advanced"
    case .about: "About"
    }
  }

  var symbol: String {
    switch self {
    case .general: "gearshape"
    case .displays: "display.2"
    case .keyboard: "keyboard"
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

private struct DisplaysSettingsView: View {
  @Bindable var store: DisplayPresentationStore
  @Bindable var configurationStore: DisplayConfigurationStore
  @State private var selectedMonitorID: MonitorID?

  var body: some View {
    Group {
      if configurationStore.configurations.isEmpty {
        emptyState
      } else {
        HSplitView {
          displayList
            .frame(minWidth: 190, idealWidth: 220, maxWidth: 270)

          detail
            .frame(minWidth: 330, maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .onAppear {
      selectFirstDisplayIfNeeded()
    }
    .onChange(of: configurationStore.configurations.map(\.id)) { _, _ in
      selectFirstDisplayIfNeeded()
    }
  }

  private var emptyState: some View {
    Group {
      if case .failed(let failure) = store.state {
        ContentUnavailableView(
          "Unable to Detect Displays",
          systemImage: "exclamationmark.triangle",
          description: Text(failure.message)
        )
      } else {
        ContentUnavailableView(
          "No External Displays",
          systemImage: "display",
          description: Text("Connect a display and MyMonitor will detect it.")
        )
      }
    }
  }

  private var displayList: some View {
    List(selection: $selectedMonitorID) {
      let connected = configurationStore.configurations.filter(\.isConnected)
      let disconnected = configurationStore.configurations.filter { !$0.isConnected }

      if !connected.isEmpty {
        Section("Connected") {
          displayRows(connected)
        }
      }

      if !disconnected.isEmpty {
        Section("Remembered") {
          displayRows(disconnected)
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
    .listStyle(.sidebar)
  }

  private func displayRows(_ configurations: [MonitorConfiguration]) -> some View {
    ForEach(configurations) { configuration in
      VStack(alignment: .leading, spacing: 2) {
        Text(configuration.name)
          .lineLimit(1)
          .truncationMode(.middle)

        Text(configuration.isConnected ? "Connected" : "Disconnected")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .tag(configuration.id)
      .accessibilityElement(children: .combine)
    }
  }

  @ViewBuilder
  private var detail: some View {
    if let selectedMonitorID,
      configurationStore.configuration(withID: selectedMonitorID) != nil
    {
      DisplayConfigurationDetailView(
        monitorID: selectedMonitorID,
        configurationStore: configurationStore
      )
    } else {
      ContentUnavailableView(
        "Select a Display",
        systemImage: "display",
        description: Text("Choose a connected or remembered display to configure it.")
      )
    }
  }

  private func selectFirstDisplayIfNeeded() {
    if let selectedMonitorID,
      configurationStore.configuration(withID: selectedMonitorID) != nil
    {
      return
    }
    selectedMonitorID = configurationStore.configurations.first?.id
  }
}

private struct DisplayConfigurationDetailView: View {
  let monitorID: MonitorID
  @Bindable var configurationStore: DisplayConfigurationStore
  @State private var showingForgetConfirmation = false

  var body: some View {
    if let configuration = configurationStore.configuration(withID: monitorID) {
      Form {
        Section {
          LabeledContent("Status", value: configuration.isConnected ? "Connected" : "Disconnected")

          if let brightness = configuration.brightness {
            LabeledContent("Brightness") {
              Text(brightness, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
            }
          }

          if let activeMethod = configuration.activeMethod {
            LabeledContent("Active method", value: activeMethod.label)
          }
        } header: {
          Text(configuration.name)
        }

        Section("Brightness Range") {
          brightnessBound(
            title: "Minimum",
            value: configuration.allowedRange.lowerBound,
            range: 0...configuration.allowedRange.upperBound,
            setValue: { configurationStore.setMinimumBrightness($0, for: monitorID) }
          )

          brightnessBound(
            title: "Maximum",
            value: configuration.allowedRange.upperBound,
            range: configuration.allowedRange.lowerBound...1,
            setValue: { configurationStore.setMaximumBrightness($0, for: monitorID) }
          )

          Text("The menu-bar slider stays within this range. Tightening a bound can move a connected display to the nearest valid brightness.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Section("Control") {
          Picker(
            "Method",
            selection: Binding(
              get: {
                configurationStore.configuration(withID: monitorID)?.preference
                  ?? .automatic
              },
              set: {
                configurationStore.setControlPreference($0, for: monitorID)
              }
            )
          ) {
            ForEach(MonitorControlPreference.allCases) { preference in
              Text(preference.label)
                .tag(preference)
            }
          }

          if let explanation = configuration.fallbackExplanation {
            Label(explanation, systemImage: "info.circle")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else if !configuration.isConnected {
            Text("The selected method will be attempted when this display reconnects.")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else if configuration.preference == .automatic {
            Text("Automatic uses hardware control when available, then software control, then display shade.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Section {
          Button("Forget Display Settings…", role: .destructive) {
            showingForgetConfirmation = true
          }
        }
      }
      .formStyle(.grouped)
      .confirmationDialog(
        "Forget settings for \(configuration.name)?",
        isPresented: $showingForgetConfirmation,
        titleVisibility: .visible
      ) {
        Button("Forget Display Settings", role: .destructive) {
          configurationStore.forgetConfiguration(for: monitorID)
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("Saved brightness, range, and control-method preferences for this display will be removed. Its current brightness will not change.")
      }
    }
  }

  private func brightnessBound(
    title: String,
    value: Double,
    range: ClosedRange<Double>,
    setValue: @escaping (Double) -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(title)
        Spacer()
        Text(value, format: .percent.precision(.fractionLength(0)))
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }

      Slider(
        value: Binding(get: { value }, set: setValue),
        in: range,
        step: 0.01
      )
      .accessibilityLabel("\(title) brightness")
      .accessibilityValue(
        Text(value, format: .percent.precision(.fractionLength(0)))
      )
    }
  }
}

private struct KeyboardSettingsView: View {
  @Bindable var configurationStore: DisplayConfigurationStore
  @Bindable var keyboardShortcutController: KeyboardShortcutController

  var body: some View {
    Form {
      Section("Global Shortcuts") {
        shortcutRow(for: .decreaseBrightness)
        shortcutRow(for: .increaseBrightness)

        if let errorMessage = keyboardShortcutController.errorMessage {
          Label(errorMessage, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.red)
        }
      }

      Section("Target Display") {
        Picker(
          "Adjust",
          selection: Binding(
            get: { keyboardShortcutController.configuration.target },
            set: { keyboardShortcutController.setTarget($0) }
          )
        ) {
          Text("Display under pointer")
            .tag(KeyboardBrightnessTarget.displayUnderPointer)
          Text("All external displays")
            .tag(KeyboardBrightnessTarget.allExternalDisplays)

          ForEach(configurationStore.configurations) { configuration in
            Text(
              configuration.isConnected
                ? configuration.name
                : "\(configuration.name) — Disconnected"
            )
            .tag(KeyboardBrightnessTarget.display(configuration.id))
          }
        }

        Text("If the pointer is not over a controllable external display, MyMonitor uses the first connected external display.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section {
        Label(
          "Custom shortcuts work globally without Accessibility or Screen Recording access. MyMonitor does not intercept the Mac's physical brightness keys.",
          systemImage: "lock.shield"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }

  private func shortcutRow(
    for action: KeyboardShortcutAction
  ) -> some View {
    LabeledContent(action.title) {
      HStack(spacing: 8) {
        ShortcutRecorderView(
          shortcut: keyboardShortcutController.shortcut(for: action),
          onChange: { keyboardShortcutController.setShortcut($0, for: action) }
        )

        if keyboardShortcutController.shortcut(for: action) != nil {
          Button {
            keyboardShortcutController.setShortcut(nil, for: action)
          } label: {
            Image(systemName: "xmark.circle.fill")
          }
          .buttonStyle(.borderless)
          .foregroundStyle(.secondary)
          .help("Clear \(action.title.lowercased()) shortcut")
          .accessibilityLabel("Clear \(action.title.lowercased()) shortcut")
        }
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
