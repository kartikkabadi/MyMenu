import AppKit
import SwiftUI

/// Owns the app's one standard, resizable Settings window.
@MainActor
final class SettingsWindowController: NSWindowController {
  private static let frameAutosaveName = "MyMonitor.SettingsWindow"
  private static let defaultSize = NSSize(width: 720, height: 500)
  private static let minimumSize = NSSize(width: 620, height: 420)

  private let launchAtLoginController: LaunchAtLoginController

  init(
    store: DisplayPresentationStore,
    configurationStore: DisplayConfigurationStore,
    launchAtLoginController: LaunchAtLoginController,
    keyboardShortcutController: KeyboardShortcutController
  ) {
    self.launchAtLoginController = launchAtLoginController

    let contentViewController = NSHostingController(
      rootView: SettingsRootView(
        store: store,
        configurationStore: configurationStore,
        launchAtLoginController: launchAtLoginController,
        keyboardShortcutController: keyboardShortcutController
      )
    )
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: Self.defaultSize),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )

    window.title = "MyMonitor Settings"
    window.contentViewController = contentViewController
    window.minSize = Self.minimumSize
    window.isReleasedWhenClosed = false
    window.tabbingMode = .disallowed
    window.collectionBehavior.insert(.moveToActiveSpace)

    let restoredFrame = window.setFrameUsingName(Self.frameAutosaveName)
    window.setFrameAutosaveName(Self.frameAutosaveName)
    if !restoredFrame {
      window.center()
    }

    super.init(window: window)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }

  func show() {
    guard let window else { return }

    launchAtLoginController.refresh()
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window.makeKeyAndOrderFront(nil)
  }
}
