import AppKit

/// Menu-bar agent: AppKit status item with a SwiftUI-hosted native popover.
@main
enum MyMonitorLauncher {
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
  }
}
