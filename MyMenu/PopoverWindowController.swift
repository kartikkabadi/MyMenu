import AppKit
import SwiftUI

private final class MenuBarPanel: NSPanel {
  var onResignKey: (() -> Void)?

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  override func resignKey() {
    super.resignKey()
    onResignKey?()
  }
}

/// Owns the menu-bar panel and keeps it inside the display that owns the status item.
@MainActor
final class PopoverWindowController: NSObject {
  let router: DisplayRouter
  let animationToken = PopoverAnimationToken()

  private var panel: NSPanel?
  private var contentViewController: NSHostingController<AnyView>?
  private var dismissMonitors: [Any] = []
  private var deactivationObserver: NSObjectProtocol?
  private var ignoreDeactivationUntil = Date.distantPast

  init(router: DisplayRouter) {
    self.router = router
    super.init()
    deactivationObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didResignActiveNotification,
      object: NSApp,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.handleDeactivation()
      }
    }
  }

  deinit {
    if let deactivationObserver {
      NotificationCenter.default.removeObserver(deactivationObserver)
    }
  }

  func toggle(relativeTo button: NSStatusBarButton) {
    if let panel {
      if panel.isVisible {
        close()
        return
      }

      // A panel can be ordered out by AppKit when the menu-bar app loses
      // activation. Do not let that stale instance swallow the next click.
      panel.orderOut(nil)
      self.panel = nil
      contentViewController = nil
    }

    animationToken.prepareForShow()

    let root = AnyView(
      BrightnessPopoverView(router: router, animationToken: animationToken)
        .frame(width: BrightnessDesign.panelWidth)
        .id(animationToken.contentGeneration)
    )
    let host = NSHostingController(rootView: root)
    host.view.wantsLayer = true
    host.view.layer?.backgroundColor = NSColor.clear.cgColor
    host.view.layer?.isOpaque = false

    let panel = MenuBarPanel(
      contentRect: NSRect(
        origin: .zero,
        size: NSSize(width: BrightnessDesign.panelWidth, height: BrightnessDesign.panelHeight)
      ),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    panel.level = .statusBar
    panel.isFloatingPanel = true
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.sharingType = .readOnly
    // The panel is keyable now, so AppKit can dismiss it naturally when the
    // user clicks another application or any other part of the desktop.
    panel.hidesOnDeactivate = true
    panel.becomesKeyOnlyIfNeeded = false
    panel.isMovable = false
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    panel.contentViewController = host

    panel.onResignKey = { [weak self, weak panel, weak button] in
      guard let self, let panel, self.panel === panel else { return }

      let mouseLocation = NSEvent.mouseLocation
      if panel.frame.contains(mouseLocation) {
        return
      }

      if let button,
         let buttonWindow = button.window,
         buttonWindow.convertToScreen(button.frame).contains(mouseLocation) {
        return
      }

      self.close()
    }

    self.panel = panel
    contentViewController = host
    installDismissMonitors(for: panel, button: button)

    let targetScreen = screen(for: button)
    position(panel, relativeTo: button, on: targetScreen)
    ignoreDeactivationUntil = Date().addingTimeInterval(0.4)
    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
    DispatchQueue.main.async { [weak self, weak panel] in
      guard let self, let panel, self.panel === panel else { return }
      self.position(panel, relativeTo: button, on: targetScreen)
      NSApp.activate(ignoringOtherApps: true)
      panel.makeKeyAndOrderFront(nil)
    }
  }

  func close() {
    removeDismissMonitors()
    panel?.orderOut(nil)
    panel = nil
    contentViewController = nil
  }

  private func handleDeactivation() {
    guard Date() >= ignoreDeactivationUntil else { return }
    close()
  }

  private func installDismissMonitors(for panel: NSPanel, button: NSStatusBarButton) {
    removeDismissMonitors()

    if let localMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown],
      handler: { [weak self, weak panel, weak button] event in
        self?.dismissIfNeeded(panel: panel, button: button)
        return event
      }
    ) {
      dismissMonitors.append(localMonitor)
    }

    if let globalMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown],
      handler: { [weak self, weak panel, weak button] _ in
        self?.dismissIfNeeded(panel: panel, button: button)
      }
    ) {
      dismissMonitors.append(globalMonitor)
    }
  }

  private func removeDismissMonitors() {
    for monitor in dismissMonitors {
      NSEvent.removeMonitor(monitor)
    }
    dismissMonitors.removeAll()
  }

  private func dismissIfNeeded(panel: NSPanel?, button: NSStatusBarButton?) {
    guard let panel, panel.isVisible else { return }

    let mouseLocation = NSEvent.mouseLocation
    if panel.frame.contains(mouseLocation) {
      return
    }

    if let button,
       let buttonWindow = button.window,
       buttonWindow.convertToScreen(button.frame).contains(mouseLocation) {
      return
    }

    close()
  }

  private func screen(for button: NSStatusBarButton) -> NSScreen? {
    guard let buttonWindow = button.window else { return NSScreen.main }

    let buttonFrame = buttonWindow.convertToScreen(button.frame)
    let buttonCenter = CGPoint(x: buttonFrame.midX, y: buttonFrame.midY)
    return NSScreen.screens.first(where: { $0.frame.contains(buttonCenter) })
      ?? buttonWindow.screen
      ?? NSScreen.main
  }

  private func position(
    _ panel: NSPanel,
    relativeTo button: NSStatusBarButton,
    on screen: NSScreen?
  ) {
    guard let screen else { return }

    var frame = panel.frame
    let bounds = screen.visibleFrame.insetBy(dx: 8, dy: 8)
    let buttonFrame = button.window?.convertToScreen(button.frame)
    let anchorX = buttonFrame?.midX ?? bounds.midX
    frame.origin.x = min(max(anchorX - frame.width / 2, bounds.minX), bounds.maxX - frame.width)
    frame.origin.y = bounds.maxY - frame.height
    panel.setFrame(frame, display: false)
  }
}
