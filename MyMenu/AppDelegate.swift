import AppKit

/// Menu-bar agent: `NSStatusItem` + `NSPopover` via `PopoverWindowController`.
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
    if let button = statusItem.button {
      let image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "MyMenu")
      image?.isTemplate = true
      button.image = image
      button.action = #selector(togglePopover(_:))
      button.target = self
    }

    // Start Window Management services
    WindowSnappingService.shared.start()
    WindowSwitcherService.shared.start()
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    .terminateNow
  }

  @objc private func togglePopover(_ sender: AnyObject?) {
    guard let button = statusItem.button else { return }
    popoverController.toggle(relativeTo: button)
  }

  func updateWindowSnappingState() {
    if AppPreferences.isWindowSnappingEnabled {
      WindowSnappingService.shared.start()
    } else {
      WindowSnappingService.shared.stop()
    }
  }

  func updateWindowSwitcherState() {
    if AppPreferences.isWindowSwitcherEnabled {
      WindowSwitcherService.shared.start()
    } else {
      WindowSwitcherService.shared.stop()
    }
  }

  func quitApp() {
    popoverController.close()
    WindowSnappingService.shared.stop()
    WindowSwitcherService.shared.stop()
    DispatchQueue.main.async { [weak self] in
      self?.router.teardownAll()
      NSApp.terminate(nil)
    }
  }
}
