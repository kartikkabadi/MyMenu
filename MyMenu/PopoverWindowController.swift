import AppKit
import SwiftUI

private final class MenuBarPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

/// Owns the menu-bar panel and keeps it inside the display that owns the status item.
@MainActor
final class PopoverWindowController: NSObject {
  let router: DisplayRouter
  let animationToken = PopoverAnimationToken()

  private var panel: NSPanel?
  private var contentViewController: NSHostingController<AnyView>?

  init(router: DisplayRouter) {
    self.router = router
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
    host.view.layer?.backgroundColor = .clear

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
    // Status-item clicks briefly move activation through SystemUIServer. Keep
    // the panel visible across that hand-off so a real mouse click cannot
    // immediately hide the panel it just opened.
    panel.hidesOnDeactivate = false
    panel.becomesKeyOnlyIfNeeded = false
    panel.isMovable = false
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    panel.contentViewController = host
    self.panel = panel
    contentViewController = host

    let targetScreen = screen(for: button)
    position(panel, relativeTo: button, on: targetScreen)
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
    panel?.orderOut(nil)
    panel = nil
    contentViewController = nil
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
