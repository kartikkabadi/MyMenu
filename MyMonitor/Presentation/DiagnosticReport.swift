import Foundation

struct DiagnosticReportContext: Equatable, Sendable {
  var appVersion: String
  var appBuild: String
  var operatingSystem: String
  var architecture: String
  var configurations: [MonitorConfiguration]
  var currentError: String?
  var focusedMonitorID: MonitorID?
}

enum DiagnosticReport {
  static func render(_ context: DiagnosticReportContext) -> String {
    var lines = [
      "MyMonitor Diagnostics",
      "=====================",
      "",
      "Application",
      "-----------",
      "Version: \(clean(context.appVersion))",
      "Build: \(clean(context.appBuild))",
      "macOS: \(clean(context.operatingSystem))",
      "Architecture: \(clean(context.architecture))",
      "",
      "Displays",
      "--------",
    ]

    if context.configurations.isEmpty {
      lines.append("No connected or remembered external displays.")
    } else {
      for configuration in context.configurations {
        let marker = configuration.id == context.focusedMonitorID ? " [focused]" : ""
        lines.append("- \(clean(configuration.name))\(marker)")
        lines.append("  Support ID: \(configuration.id.rawValue)")
        lines.append("  Connection: \(configuration.isConnected ? "connected" : "disconnected")")
        if let brightness = configuration.brightness {
          lines.append("  Brightness: \(percent(brightness))")
        } else {
          lines.append("  Brightness: unavailable")
        }
        lines.append(
          "  Allowed range: \(percent(configuration.allowedRange.lowerBound))–\(percent(configuration.allowedRange.upperBound))"
        )
        lines.append("  Requested method: \(configuration.preference.label)")
        lines.append("  Active method: \(configuration.activeMethod?.label ?? "unavailable")")
      }
    }

    if let currentError = context.currentError, !currentError.isEmpty {
      lines += [
        "",
        "Current Error",
        "-------------",
        clean(currentError),
      ]
    }

    lines += [
      "",
      "Privacy",
      "-------",
      "This report contains MyMonitor version, macOS version, architecture, and external-display control state. It does not include window titles, clipboard data, user documents, account information, or unrelated system inventory.",
      "",
    ]

    return lines.joined(separator: "\n")
  }

  private static func clean(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\r", with: " ")
      .replacingOccurrences(of: "\n", with: " ")
      .trimmingCharacters(in: .whitespaces)
  }

  private static func percent(_ value: Double) -> String {
    "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
  }
}
