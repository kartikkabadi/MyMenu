import AppKit
import CoreGraphics
import QuartzCore

/// Per-external-display black overlay dimming (Tier 3).
@MainActor
final class OverlayBrightnessBackend: BrightnessBackend {
  static let tier: BrightnessTier = .overlay

  private static let settleAnimationDuration: TimeInterval = 0.12
  /// `.floating` + `fullScreenAuxiliary` — best fit for Safari fullscreen video Spaces (mirror mode).
  private static let overlayWindowLevel = NSWindow.Level.floating

  private let displayID: CGDirectDisplayID
  private var panel: NSPanel?
  private var shadeView: NSView?
  private var currentBrightness: Double = 0
  private var suppressOrderFront = false

  init(displayID: CGDirectDisplayID) {
    self.displayID = displayID
    guard !Self.isBuiltin(displayID) else { return }
    ensurePanel()
    applyBrightness(currentBrightness, animated: false)
  }

  static func probe(displayID: CGDirectDisplayID) -> Bool {
    !isBuiltin(displayID)
  }

  func setBrightness(_ value: Double, animated: Bool) {
    let clamped = min(max(value, 0), 1)
    currentBrightness = clamped
    ensurePanel()
    applyBrightness(clamped, animated: animated)
  }

  func teardown() {
    panel?.orderOut(nil)
    panel = nil
    shadeView = nil
  }

  func setSuppressOrderFront(_ suppress: Bool) {
    suppressOrderFront = suppress
  }

  /// During Space swipe: only reaffirm alpha — no `orderFront` / frame churn.
  func reaffirmAlphaDuringTransition() {
    guard currentBrightness > 0.001 else { return }
    applyBrightness(currentBrightness, animated: false)
  }

  /// After transition settles: one layout pass + single order-front.
  func finalizeAfterSpaceTransition() {
    suppressOrderFront = false
    syncFrameIfNeeded()
    applyBrightness(currentBrightness, animated: false)
    if currentBrightness > 0.001 {
      panel?.orderFrontRegardless()
    }
  }

  func stabilizeForSpaceTransition() {
    reaffirmAlphaDuringTransition()
  }

  func syncToScreen() {
    finalizeAfterSpaceTransition()
  }

  func orderFrontIfNeeded() {
    guard currentBrightness > 0.001, !suppressOrderFront else { return }
    applyBrightness(currentBrightness, animated: false)
    panel?.orderFrontRegardless()
  }

  // MARK: - Panel lifecycle

  private func ensurePanel() {
    guard !Self.isBuiltin(displayID) else { return }
    guard let screen = Self.screen(for: displayID) else { return }

    if panel != nil {
      syncFrameIfNeeded()
      return
    }

    let frame = screen.frame
    let shade = NSView(frame: NSRect(origin: .zero, size: frame.size))
    shade.wantsLayer = true
    shade.layer?.backgroundColor = NSColor.black.cgColor
    shade.alphaValue = CGFloat(currentBrightness)

    let overlayPanel = NSPanel(
      contentRect: frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false,
      screen: screen
    )
    overlayPanel.level = Self.overlayWindowLevel
    overlayPanel.isOpaque = false
    overlayPanel.backgroundColor = .clear
    overlayPanel.ignoresMouseEvents = true
    overlayPanel.isFloatingPanel = true
    overlayPanel.hidesOnDeactivate = false
    overlayPanel.animationBehavior = .none
    overlayPanel.collectionBehavior = [
      .canJoinAllSpaces,
      .stationary,
      .ignoresCycle,
      .fullScreenAuxiliary,
    ]
    overlayPanel.hasShadow = false
    overlayPanel.isReleasedWhenClosed = false
    overlayPanel.contentView = shade

    shadeView = shade
    panel = overlayPanel
    if !suppressOrderFront {
      overlayPanel.orderFrontRegardless()
    }
  }

  private func syncFrameIfNeeded() {
    guard let panel, let shadeView, let screen = Self.screen(for: displayID) else { return }
    let target = screen.frame
    guard panel.frame != target || panel.screen != screen else { return }

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    panel.setFrame(target, display: false)
    shadeView.frame = NSRect(origin: .zero, size: target.size)
    CATransaction.commit()
  }

  private func applyBrightness(_ value: Double, animated: Bool) {
    guard let shadeView else { return }
    let alpha = CGFloat(value)

    if !animated, abs(shadeView.alphaValue - alpha) < 0.0001 {
      if alpha > 0, !suppressOrderFront { panel?.orderFrontRegardless() }
      return
    }

    if animated {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = Self.settleAnimationDuration
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        shadeView.animator().alphaValue = alpha
      }
    } else {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      shadeView.alphaValue = alpha
      CATransaction.commit()
    }

    if alpha > 0, !suppressOrderFront {
      panel?.orderFrontRegardless()
    }
  }

  private static func isBuiltin(_ displayID: CGDirectDisplayID) -> Bool {
    CGDisplayIsBuiltin(displayID) != 0
  }

  private static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
    let key = NSDeviceDescriptionKey("NSScreenNumber")
    for screen in NSScreen.screens {
      guard let number = screen.deviceDescription[key] as? NSNumber else { continue }
      if CGDirectDisplayID(number.uint32Value) == displayID {
        return screen
      }
    }
    return nil
  }
}
