import AppKit

/// Small menu-bar agent for external-monitor brightness control.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  static private(set) var shared: AppDelegate!

  private let presentationStore: DisplayPresentationStore
  private var statusItem: NSStatusItem!
  private var popoverController: PopoverWindowController!
  private var settingsController: SettingsWindowController!

  override init() {
    let router = DisplayRouter()
    let controller = DisplayRouterAdapter(router: router)
    presentationStore = DisplayPresentationStore(controller: controller)
    super.init()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    Self.shared = self
    popoverController = PopoverWindowController(store: presentationStore)
    settingsController = SettingsWindowController(store: presentationStore)

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

  func showSettings() {
    popoverController.close()
    settingsController.show()
  }

  func quitApp() {
    popoverController.close()
    settingsController.close()
    presentationStore.teardown()
    NSApp.terminate(nil)
  }
}
