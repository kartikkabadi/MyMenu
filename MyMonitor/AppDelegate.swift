import AppKit

/// Small menu-bar agent for external-monitor brightness control.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  static private(set) var shared: AppDelegate!

  let router = DisplayRouter()

  private var statusItem: NSStatusItem!
  private var popoverController: PopoverWindowController!

  func applicationDidFinishLaunching(_ notification: Notification) {
    Self.shared = self
    popoverController = PopoverWindowController(router: router)

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    guard let button = statusItem.button else { return }

    let image = NSImage(
      systemSymbolName: "display",
      accessibilityDescription: "MyMonitor"
    )
    image?.isTemplate = true
    button.image = image
    button.imagePosition = .imageOnly
    button.target = self
    button.action = #selector(togglePopover(_:))
    button.sendAction(on: [.leftMouseUp])
    button.toolTip = "MyMonitor"
  }

  @objc private func togglePopover(_ sender: AnyObject?) {
    guard let button = statusItem.button else { return }
    popoverController.toggle(relativeTo: button)
  }

  func quitApp() {
    popoverController.close()
    router.teardownAll()
    NSApp.terminate(nil)
  }
}
