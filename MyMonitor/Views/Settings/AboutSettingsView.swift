import AppKit
import SwiftUI

struct AboutSettingsView: View {
  @State private var showingAttribution = false

  var body: some View {
    Form {
      Section {
        HStack(alignment: .center, spacing: 16) {
          Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .scaledToFit()
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)

          VStack(alignment: .leading, spacing: 4) {
            Text("MyMonitor")
              .font(.title2.weight(.semibold))

            Text(versionText)
              .foregroundStyle(.secondary)

            Text("External-monitor brightness control for macOS.")
              .foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 4)
      }

      Section("Project") {
        Link(
          "View Source",
          destination: URL(string: "https://github.com/kartikkabadi/MyMonitor")!
        )

        Link(
          "MyMonitor License",
          destination: URL(string: "https://github.com/kartikkabadi/MyMonitor/blob/main/LICENSE")!
        )

        Button("Third-Party Attribution…") {
          showingAttribution = true
        }
      }

      Section("Privacy") {
        LabeledContent("Processing", value: "On this Mac")
        LabeledContent("Analytics", value: "None")
        LabeledContent("Accounts", value: "None")
        LabeledContent("Network service", value: "None")

        Text("MyMonitor stores display and shortcut preferences locally. Diagnostic reports are created only when you explicitly copy or export them.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section {
        Text("MyMonitor is not affiliated with Apple or MonitorControl.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .sheet(isPresented: $showingAttribution) {
      ThirdPartyAttributionView()
    }
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

private struct ThirdPartyAttributionView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Third-Party Attribution")
          .font(.headline)

        Spacer()

        Button("Done") {
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
      }
      .padding(16)

      Divider()

      Form {
        Section("MonitorControl — Arm64 DDC") {
          Text("Arm64DDC.swift and Bridging-Header.h are adapted from MonitorControl under the MIT License.")

          Text("Copyright © MonitorControl contributors (@JoniVR, @theOneyouseek, @waydabber, and others).")
            .foregroundStyle(.secondary)

          Link(
            "View MonitorControl Source",
            destination: URL(string: "https://github.com/MonitorControl/MonitorControl")!
          )

          Link(
            "View MonitorControl License",
            destination: URL(string: "https://github.com/MonitorControl/MonitorControl/blob/main/LICENSE")!
          )
        }

        Section("Usage") {
          Text("MyMonitor uses the adapted code only for external-monitor brightness through MCCS VCP 0x10 (luminance).")

          Text("MyMonitor is not affiliated with MonitorControl.")
            .foregroundStyle(.secondary)
        }

        Section {
          Text("The complete third-party notice is also included in MyMonitor/ThirdParty/README.md in the source repository and must remain with redistributed builds.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .formStyle(.grouped)
    }
    .frame(width: 540, height: 410)
  }
}
