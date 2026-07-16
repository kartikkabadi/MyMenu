import AppKit
import SwiftUI

/// Owns one transient native popover anchored to the menu-bar status item.
@MainActor
final class PopoverWindowController: NSObject {
  let router: DisplayRouter

  private let popover: NSPopover
  private let contentViewController: NSHostingController<BrightnessPopoverView>

  init(router: DisplayRouter) {
    self.router = router
    self.popover = NSPopover()
    self.contentViewController = NSHostingController(
      rootView: BrightnessPopoverView(router: router)
    )
    super.init()

    popover.behavior = .transient
    popover.animates = true
    popover.contentSize = NSSize(
      width: BrightnessDesign.panelWidth,
      height: BrightnessDesign.panelHeight
    )
    popover.contentViewController = contentViewController
  }

  func toggle(relativeTo button: NSStatusBarButton) {
    if popover.isShown {
      close()
      return
    }

    router.reconfigure()
    popover.show(
      relativeTo: button.bounds,
      of: button,
      preferredEdge: .minY
    )
    NSApp.activate(ignoringOtherApps: true)
  }

  func close() {
    popover.performClose(nil)
  }
}
