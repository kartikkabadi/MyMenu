import AppKit

/// Menu-bar agent: `NSStatusItem` + a lightweight glass panel.
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
      let image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "MyMonitor")
      image?.isTemplate = true
      button.image = image
      button.action = #selector(togglePopover(_:))
      button.target = self
    }

    // Start Window Management services
    WindowSnappingService.shared.start()
    WindowSwitcherService.shared.start()

    // Explain the product before a fresh install asks for optional macOS
    // privacy access. The same panel can be reopened from the status item.
    guard !AppPreferences.hasCompletedOnboarding else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self, let button = self.statusItem.button else { return }
      self.popoverController.toggle(relativeTo: button)
    }
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
