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
