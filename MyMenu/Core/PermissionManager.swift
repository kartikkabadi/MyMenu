import Foundation
import ApplicationServices
import CoreGraphics

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
    _ = CGRequestScreenCaptureAccess()
  }
}
