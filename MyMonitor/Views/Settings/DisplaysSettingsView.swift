import SwiftUI

struct DisplaysSettingsView: View {
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
          LabeledContent(
            "Status",
            value: configuration.isConnected ? "Connected" : "Disconnected"
          )

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
