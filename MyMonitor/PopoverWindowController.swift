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

    contentViewController.sizingOptions = [.preferredContentSize]

    popover.behavior = .transient
    popover.animates = true
    popover.contentViewController = contentViewController
    prepareContentSize()
  }

  func toggle(relativeTo button: NSStatusBarButton) {
    if popover.isShown {
      close()
      return
    }

    prepareContentSize()
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

  private func prepareContentSize() {
    contentViewController.view.layoutSubtreeIfNeeded()

    let fittingSize = contentViewController.view.fittingSize
    let height = min(
      max(ceil(fittingSize.height), 1),
      BrightnessDesign.maximumPopoverHeight
    )

    popover.contentSize = NSSize(
      width: BrightnessDesign.popoverWidth,
      height: height
    )
  }
}
