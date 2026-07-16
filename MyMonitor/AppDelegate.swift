import AppKit

/// Small menu-bar agent for external-monitor brightness control.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  static private(set) var shared: AppDelegate!

  private let presentationStore: DisplayPresentationStore
  private let configurationStore: DisplayConfigurationStore
  private let launchAtLoginController: LaunchAtLoginController
  private let keyboardShortcutController: KeyboardShortcutController
  private let keyboardBrightnessCoordinator: KeyboardBrightnessCoordinator
  private var statusItem: NSStatusItem!
  private var popoverController: PopoverWindowController!
  private var settingsController: SettingsWindowController!

  override init() {
    let router = DisplayRouter()
    let controller = DisplayRouterAdapter(router: router)
    let presentationStore = DisplayPresentationStore(controller: controller)
    let keyboardShortcutController = KeyboardShortcutController(
      service: CarbonGlobalHotKeyService(),
      persistence: SystemKeyboardShortcutPreferences()
    )
    let keyboardBrightnessCoordinator = KeyboardBrightnessCoordinator(
      store: presentationStore
    )

    self.presentationStore = presentationStore
    configurationStore = DisplayConfigurationStore(controller: controller)
    launchAtLoginController = LaunchAtLoginController(
      service: SystemLaunchAtLoginService()
    )
    self.keyboardShortcutController = keyboardShortcutController
    self.keyboardBrightnessCoordinator = keyboardBrightnessCoordinator
    super.init()

    keyboardShortcutController.actionHandler = { [weak keyboardBrightnessCoordinator] action, target in
      keyboardBrightnessCoordinator?.perform(action, target: target)
    }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    Self.shared = self
    popoverController = PopoverWindowController(store: presentationStore)
    settingsController = SettingsWindowController(
      store: presentationStore,
      configurationStore: configurationStore,
      launchAtLoginController: launchAtLoginController,
      keyboardShortcutController: keyboardShortcutController
    )

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
    keyboardShortcutController.teardown()
    presentationStore.teardown()
    NSApp.terminate(nil)
  }
}
