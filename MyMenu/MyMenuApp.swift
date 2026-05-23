import AppKit

/// Menu-bar agent: AppKit status item + popover (matches One Menu architecture).
@main
enum MyMenuLauncher {
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
  }
}
