import AppKit
import SwiftUI

/// Owns one transient native popover anchored to the menu-bar status item.
@MainActor
final class PopoverWindowController: NSObject {
  let store: DisplayPresentationStore

  private let popover: NSPopover
  private let contentViewController: NSHostingController<BrightnessPopoverView>

  init(store: DisplayPresentationStore) {
    self.store = store
    self.popover = NSPopover()
    self.contentViewController = NSHostingController(
      rootView: BrightnessPopoverView(store: store)
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

    store.refresh()
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
