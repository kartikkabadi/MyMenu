import SwiftUI

struct KeyboardSettingsView: View {
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
            .accessibilityIdentifier("keyboard.shortcutError")
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
        .accessibilityIdentifier("keyboard.targetDisplay")

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
          accessibilityLabel: action.title,
          accessibilityIdentifier: "keyboard.shortcut.\(action.rawValue)",
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
          .accessibilityIdentifier("keyboard.clearShortcut.\(action.rawValue)")
        }
      }
    }
  }
}
