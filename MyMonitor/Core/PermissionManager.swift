import Foundation
import ApplicationServices
import CoreGraphics
import AppKit

class PermissionManager {
  static let shared = PermissionManager()

  private init() {}

  var hasAccessibilityAccess: Bool {
    AXIsProcessTrusted()
  }

  func requestAccessibilityAccess() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    AXIsProcessTrustedWithOptions(options as CFDictionary)
  }

  var hasScreenRecordingAccess: Bool {
    CGPreflightScreenCaptureAccess()
  }

  func requestScreenRecordingAccess() {
    guard !hasScreenRecordingAccess else { return }

    // CGWindowListCopyWindowInfo filters protected metadata without showing a
    // prompt. Request access first so macOS can register the app with TCC,
    // then take the user to the pane where the grant can actually be made.
    _ = CGRequestScreenCaptureAccess()
    openScreenRecordingSettings()
  }

  func openScreenRecordingSettings() {
    let urls = [
      "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
      "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
    ].compactMap(URL.init(string:))

    for url in urls where NSWorkspace.shared.open(url) {
      break
    }
  }
}
