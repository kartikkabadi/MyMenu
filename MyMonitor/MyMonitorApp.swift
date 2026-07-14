import AppKit

/// Menu-bar agent: AppKit status item + SwiftUI glass panel.
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
