import AppKit
import os
import SwiftUI

/// Owns one transient native popover anchored to the menu-bar status item.
@MainActor
final class PopoverWindowController: NSObject {
  let store: DisplayPresentationStore

  private let popover: NSPopover
  private let contentViewController: PopoverHostingController<BrightnessPopoverView>
  private let performanceLog = OSLog(
    subsystem: "com.mymonitor.MyMonitor",
    category: "Frontend"
  )
  private var presentationSignpostID: OSSignpostID?

  init(store: DisplayPresentationStore) {
    self.store = store
    self.popover = NSPopover()
    self.contentViewController = PopoverHostingController(
      rootView: BrightnessPopoverView(store: store)
    )
    super.init()

    contentViewController.sizingOptions = [.preferredContentSize]
    contentViewController.onPreferredContentSizeChange = { [weak self] size in
      self?.applyContentSize(size)
    }
    contentViewController.onViewDidAppear = { [weak self] in
      self?.finishPresentationSignpost()
    }

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

    beginPresentationSignpost()
    prepareContentSize()
    popover.show(
      relativeTo: button.bounds,
      of: button,
      preferredEdge: .minY
    )
    NSApp.activate(ignoringOtherApps: true)
  }

  func close() {
    finishPresentationSignpost()
    popover.performClose(nil)
  }

  private func prepareContentSize() {
    contentViewController.view.layoutSubtreeIfNeeded()

    let preferred = contentViewController.preferredContentSize
    let measured = preferred.height > 1
      ? preferred
      : contentViewController.view.fittingSize
    applyContentSize(measured)
  }

  private func applyContentSize(_ size: NSSize) {
    let nextSize = NSSize(
      width: BrightnessDesign.popoverWidth,
      height: min(
        max(ceil(size.height), 1),
        BrightnessDesign.maximumPopoverHeight
      )
    )

    guard abs(popover.contentSize.width - nextSize.width) > 0.5
      || abs(popover.contentSize.height - nextSize.height) > 0.5
    else {
      return
    }

    popover.contentSize = nextSize
  }

  private func beginPresentationSignpost() {
    finishPresentationSignpost()

    let signpostID = OSSignpostID(log: performanceLog)
    presentationSignpostID = signpostID
    os_signpost(
      .begin,
      log: performanceLog,
      name: "Popover Presentation",
      signpostID: signpostID
    )
  }

  private func finishPresentationSignpost() {
    guard let signpostID = presentationSignpostID else { return }
    os_signpost(
      .end,
      log: performanceLog,
      name: "Popover Presentation",
      signpostID: signpostID
    )
    presentationSignpostID = nil
  }
}

@MainActor
private final class PopoverHostingController<Content: View>: NSHostingController<Content> {
  var onPreferredContentSizeChange: ((NSSize) -> Void)?
  var onViewDidAppear: (() -> Void)?

  override var preferredContentSize: NSSize {
    didSet {
      guard oldValue != preferredContentSize else { return }
      onPreferredContentSizeChange?(preferredContentSize)
    }
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    onViewDidAppear?()
  }
}
