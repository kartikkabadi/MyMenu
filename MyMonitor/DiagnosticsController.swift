import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class DiagnosticsController {
  private(set) var focusedMonitorID: MonitorID?
  private(set) var statusMessage: String?
  private(set) var errorMessage: String?

  @ObservationIgnored
  private let presentationStore: DisplayPresentationStore

  @ObservationIgnored
  private let configurationStore: DisplayConfigurationStore

  init(
    presentationStore: DisplayPresentationStore,
    configurationStore: DisplayConfigurationStore
  ) {
    self.presentationStore = presentationStore
    self.configurationStore = configurationStore
  }

  var focusedConfiguration: MonitorConfiguration? {
    guard let focusedMonitorID else { return nil }
    return configurationStore.configuration(withID: focusedMonitorID)
  }

  var reportText: String {
    DiagnosticReport.render(
      DiagnosticReportContext(
        appVersion: bundleValue("CFBundleShortVersionString", fallback: "Development"),
        appBuild: bundleValue("CFBundleVersion", fallback: "Development"),
        operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
        architecture: architecture,
        configurations: configurationStore.configurations,
        currentError: currentError,
        focusedMonitorID: focusedMonitorID
      )
    )
  }

  func focus(on monitorID: MonitorID?) {
    focusedMonitorID = monitorID
    statusMessage = nil
    errorMessage = nil
  }

  func retryHardwareControl() {
    if let focusedMonitorID {
      presentationStore.retryControl(for: focusedMonitorID)
      statusMessage = "Retrying control for \(focusedDisplayName)…"
    } else {
      presentationStore.retryAllControls()
      statusMessage = "Retrying control for connected displays…"
    }
    errorMessage = nil
  }

  func copyReport() {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    guard pasteboard.setString(reportText, forType: .string) else {
      statusMessage = nil
      errorMessage = "MyMonitor could not copy the diagnostic summary."
      return
    }
    errorMessage = nil
    statusMessage = "Diagnostic summary copied."
  }

  func exportReport() {
    let panel = NSSavePanel()
    panel.title = "Export MyMonitor Diagnostic Report"
    panel.nameFieldStringValue = "MyMonitor-Diagnostics.txt"
    panel.allowedContentTypes = [.plainText]
    panel.canCreateDirectories = true

    guard panel.runModal() == .OK, let url = panel.url else { return }

    do {
      try reportText.write(to: url, atomically: true, encoding: .utf8)
      errorMessage = nil
      statusMessage = "Diagnostic report exported."
    } catch {
      statusMessage = nil
      errorMessage = "MyMonitor could not export the diagnostic report: \(error.localizedDescription)"
    }
  }

  func resetAllDisplayPreferences() {
    configurationStore.resetAllConfigurations()
    focusedMonitorID = nil
    errorMessage = nil
    statusMessage = "All saved display preferences were reset. Current brightness was not changed."
  }

  func clearStatus() {
    statusMessage = nil
    errorMessage = nil
  }

  private var focusedDisplayName: String {
    focusedConfiguration?.name ?? "the selected display"
  }

  private var currentError: String? {
    if case .failed(let failure) = presentationStore.state {
      return failure.message
    }

    guard let focusedMonitorID,
      let monitor = presentationStore.monitor(withID: focusedMonitorID),
      case .unavailable(let message, _) = monitor.control
    else {
      return nil
    }
    return message
  }

  private func bundleValue(_ key: String, fallback: String) -> String {
    Bundle.main.object(forInfoDictionaryKey: key) as? String ?? fallback
  }

  private var architecture: String {
#if arch(arm64)
    "arm64"
#elseif arch(x86_64)
    "x86_64"
#else
    "unknown"
#endif
  }
}
