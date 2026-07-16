import SwiftUI

struct GeneralSettingsView: View {
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
        .accessibilityIdentifier("general.launchAtLogin")

        if let statusMessage {
          Label(statusMessage, systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("general.launchAtLoginStatus")
        }

        if let errorMessage = launchAtLoginController.errorMessage {
          Label(errorMessage, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.red)
            .accessibilityIdentifier("general.launchAtLoginError")
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
      String(
        localized: "Approval is required in System Settings › General › Login Items."
      )
    case .unavailable:
      String(localized: "Launch at login is unavailable for this build.")
    case .notRegistered, .enabled:
      nil
    }
  }
}
