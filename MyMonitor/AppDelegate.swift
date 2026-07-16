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
  private let settingsNavigationModel: SettingsNavigationModel
  private let diagnosticsController: DiagnosticsController
  private var statusItem: NSStatusItem!
  private var popoverController: PopoverWindowController!
  private var settingsController: SettingsWindowController!
  private var hasTornDown = false

  override init() {
    let router = DisplayRouter()
    let controller = DisplayRouterAdapter(router: router)
    let presentationStore = DisplayPresentationStore(controller: controller)
    let configurationStore = DisplayConfigurationStore(controller: controller)
    let keyboardShortcutController = KeyboardShortcutController(
      service: CarbonGlobalHotKeyService(),
      persistence: SystemKeyboardShortcutPreferences()
    )
    let keyboardBrightnessCoordinator = KeyboardBrightnessCoordinator(
      store: presentationStore
    )

    self.presentationStore = presentationStore
    self.configurationStore = configurationStore
    launchAtLoginController = LaunchAtLoginController(
      service: SystemLaunchAtLoginService()
    )
    self.keyboardShortcutController = keyboardShortcutController
    self.keyboardBrightnessCoordinator = keyboardBrightnessCoordinator
    settingsNavigationModel = SettingsNavigationModel()
    diagnosticsController = DiagnosticsController(
      presentationStore: presentationStore,
      configurationStore: configurationStore
    )
    super.init()

    keyboardShortcutController.actionHandler = { [weak keyboardBrightnessCoordinator] action, target in
      keyboardBrightnessCoordinator?.perform(action, target: target)
    }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    _ = notification
    Self.shared = self
    popoverController = PopoverWindowController(store: presentationStore)
    settingsController = SettingsWindowController(
      store: presentationStore,
      configurationStore: configurationStore,
      launchAtLoginController: launchAtLoginController,
      keyboardShortcutController: keyboardShortcutController,
      navigationModel: settingsNavigationModel,
      diagnosticsController: diagnosticsController
    )

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    guard let button = statusItem.button else { return }

    let appName = String(localized: "MyMonitor")
    let accessibilityHelp = String(
      localized: "Open external display brightness controls."
    )
    let image = NSImage(
      systemSymbolName: "display",
      accessibilityDescription: appName
    )
    image?.isTemplate = true
    button.image = image
    button.imagePosition = .imageOnly
    button.target = self
    button.action = #selector(togglePopover(_:))
    button.sendAction(on: [.leftMouseUp])
    button.toolTip = appName
    button.setAccessibilityLabel(appName)
    button.setAccessibilityHelp(accessibilityHelp)
    button.setAccessibilityIdentifier("mymonitor.statusItem")
  }

  func applicationWillTerminate(_ notification: Notification) {
    _ = notification
    teardown()
  }

  @objc private func togglePopover(_ sender: AnyObject?) {
    _ = sender
    guard !hasTornDown, let button = statusItem?.button else { return }
    popoverController.toggle(relativeTo: button)
  }

  func showSettings() {
    guard !hasTornDown else { return }
    popoverController.close()
    settingsController.show()
  }

  func showDiagnostics(for monitorID: MonitorID? = nil) {
    guard !hasTornDown else { return }
    popoverController.close()
    diagnosticsController.focus(on: monitorID)
    settingsController.show(destination: .advanced)
  }

  func quitApp() {
    teardown()
    NSApp.terminate(nil)
  }

  private func teardown() {
    guard !hasTornDown else { return }
    hasTornDown = true

    popoverController?.close()
    settingsController?.close()
    keyboardShortcutController.teardown()
    presentationStore.teardown()

    if let statusItem {
      NSStatusBar.system.removeStatusItem(statusItem)
      self.statusItem = nil
    }
  }
}
