import AppKit
import SwiftUI

/// One Menu–style popover host: clear window chrome, recreate SwiftUI on each `popoverWillShow`.
@MainActor
final class PopoverWindowController: NSObject, NSPopoverDelegate {
  let router: DisplayRouter
  let animationToken = PopoverAnimationToken()

  let popover: NSPopover

  init(router: DisplayRouter) {
    self.router = router
    popover = NSPopover()
    super.init()
    popover.behavior = .transient
    popover.animates = true
    popover.delegate = self
    installContentViewController()
  }

  func toggle(relativeTo button: NSStatusBarButton) {
    if popover.isShown {
      popover.performClose(nil)
      return
    }
    installContentViewController()
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    NSApp.activate(ignoringOtherApps: true)
  }

  func close() {
    popover.performClose(nil)
  }

  // MARK: - NSPopoverDelegate

  func popoverWillShow(_ notification: Notification) {
    animationToken.prepareForShow()
  }

  func popoverDidShow(_ notification: Notification) {
    configurePopoverWindow()
  }

  // MARK: - Content

  private func installContentViewController() {
    let root = BrightnessPopoverView(router: router, animationToken: animationToken)
      .frame(width: BrightnessDesign.panelWidth)
      .id(animationToken.contentGeneration)

    let host = NSHostingController(rootView: root)
    host.view.wantsLayer = true
    host.view.layer?.backgroundColor = .clear

    popover.contentViewController = host
    popover.contentSize = NSSize(
      width: BrightnessDesign.panelWidth,
      height: BrightnessDesign.panelHeight
    )
  }

  private func configurePopoverWindow() {
    guard let window = popover.contentViewController?.view.window else { return }
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.sharingType = .readOnly
  }
}
