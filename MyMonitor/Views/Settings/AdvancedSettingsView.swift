import SwiftUI

struct AdvancedSettingsView: View {
  @Bindable var store: DisplayPresentationStore
  @Bindable var diagnosticsController: DiagnosticsController
  @State private var showingResetConfirmation = false

  var body: some View {
    Form {
      if let focusedConfiguration = diagnosticsController.focusedConfiguration {
        Section("Focused Display") {
          LabeledContent("Display", value: focusedConfiguration.name)
          LabeledContent(
            "Status",
            value: focusedConfiguration.isConnected ? "Connected" : "Disconnected"
          )
          Button("Clear Focus") {
            diagnosticsController.focus(on: nil)
          }
        }
      }

      Section("Recovery") {
        Button(retryTitle) {
          diagnosticsController.retryHardwareControl()
        }
        .disabled(
          diagnosticsController.focusedMonitorID != nil
            && diagnosticsController.focusedConfiguration?.isConnected != true
        )

        Button("Re-detect Displays") {
          store.refresh()
          diagnosticsController.clearStatus()
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

      Section("Diagnostics") {
        Button("Copy Diagnostic Summary") {
          diagnosticsController.copyReport()
        }

        Button("Export Diagnostic Report…") {
          diagnosticsController.exportReport()
        }

        Text("Reports contain MyMonitor, macOS, architecture, and external-display control state only. They exclude window titles, clipboard data, documents, accounts, and unrelated system inventory.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if let statusMessage = diagnosticsController.statusMessage {
        Section {
          Label(statusMessage, systemImage: "info.circle")
            .foregroundStyle(.secondary)
        }
      }

      if let errorMessage = diagnosticsController.errorMessage {
        Section {
          Label(errorMessage, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
        }
      }

      Section("Reset") {
        Button("Reset All Display Preferences…", role: .destructive) {
          showingResetConfirmation = true
        }

        Text("This removes saved brightness, range, and control-method preferences. It does not change current physical brightness.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .confirmationDialog(
      "Reset all display preferences?",
      isPresented: $showingResetConfirmation,
      titleVisibility: .visible
    ) {
      Button("Reset All Display Preferences", role: .destructive) {
        diagnosticsController.resetAllDisplayPreferences()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Saved settings for every connected and remembered display will be removed. Current brightness will not change.")
    }
  }

  private var retryTitle: String {
    if let focusedConfiguration = diagnosticsController.focusedConfiguration {
      return "Retry Control for \(focusedConfiguration.name)"
    }
    return "Retry Hardware Control"
  }
}
