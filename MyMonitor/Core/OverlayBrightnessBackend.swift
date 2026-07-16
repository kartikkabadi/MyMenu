import AppKit
import CoreGraphics
import QuartzCore

/// Per-external-display black overlay used when hardware and gamma control are unavailable.
@MainActor
final class OverlayBrightnessBackend: BrightnessBackend {
  static let tier: BrightnessTier = .overlay

  private static let settleAnimationDuration: TimeInterval = 0.12
  private static let overlayWindowLevel = NSWindow.Level.floating

  private let displayID: CGDirectDisplayID
  private var panel: NSPanel?
  private var shadeView: NSView?
  private var currentBrightness: Double = 1
  private var suppressOrderFront = false
  private var animationGeneration: UInt64 = 0
  private var hasTornDown = false

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
    guard !hasTornDown else { return }
    let clamped = min(max(value, 0), 1)
    currentBrightness = clamped
    ensurePanel()
    applyBrightness(clamped, animated: animated)
  }

  func teardown() {
    guard !hasTornDown else { return }
    hasTornDown = true
    animationGeneration &+= 1
    shadeView?.layer?.removeAllAnimations()
    panel?.orderOut(nil)
    panel?.close()
    panel = nil
    shadeView = nil
  }

  func setSuppressOrderFront(_ suppress: Bool) {
    guard !hasTornDown else { return }
    suppressOrderFront = suppress
  }

  /// During a Space swipe, only reaffirm opacity—do not churn window order or frames.
  func reaffirmAlphaDuringTransition() {
    guard !hasTornDown, currentBrightness < 0.999 else { return }
    applyBrightness(currentBrightness, animated: false)
  }

  /// After a Space transition settles, perform one layout pass and restore the shade if needed.
  func finalizeAfterSpaceTransition() {
    guard !hasTornDown else { return }
    suppressOrderFront = false
    syncFrameIfNeeded()
    applyBrightness(currentBrightness, animated: false)
  }

  func stabilizeForSpaceTransition() {
    reaffirmAlphaDuringTransition()
  }

  func syncToScreen() {
    finalizeAfterSpaceTransition()
  }

  func orderFrontIfNeeded() {
    guard !hasTornDown, currentBrightness < 0.999, !suppressOrderFront else { return }
    applyBrightness(currentBrightness, animated: false)
    panel?.orderFrontRegardless()
  }

  // MARK: - Panel lifecycle

  private func ensurePanel() {
    guard !hasTornDown, !Self.isBuiltin(displayID) else { return }
    guard let screen = Self.screen(for: displayID) else { return }

    if panel != nil {
      syncFrameIfNeeded()
      return
    }

    let frame = screen.frame
    let shade = NSView(frame: NSRect(origin: .zero, size: frame.size))
    shade.wantsLayer = true
    shade.layer?.backgroundColor = NSColor.black.cgColor
    shade.alphaValue = CGFloat(1 - currentBrightness)

    let overlayPanel = NSPanel(
      contentRect: frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false,
      screen: screen
    )
    overlayPanel.level = Self.overlayWindowLevel
    overlayPanel.sharingType = .readOnly
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

    if currentBrightness < 0.999, !suppressOrderFront {
      overlayPanel.orderFrontRegardless()
    }
  }

  private func syncFrameIfNeeded() {
    guard !hasTornDown,
      let panel,
      let shadeView,
      let screen = Self.screen(for: displayID)
    else {
      return
    }
    let target = screen.frame
    guard panel.frame != target || panel.screen != screen else { return }

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    panel.setFrame(target, display: false)
    shadeView.frame = NSRect(origin: .zero, size: target.size)
    CATransaction.commit()
  }

  private func applyBrightness(_ value: Double, animated: Bool) {
    guard !hasTornDown, let shadeView, let panel else { return }
    let alpha = CGFloat(1 - min(max(value, 0), 1))

    animationGeneration &+= 1
    let generation = animationGeneration

    if !animated {
      // A direct manipulation or topology update supersedes any in-flight settle animation.
      shadeView.layer?.removeAllAnimations()
    }

    if !animated, abs(shadeView.alphaValue - alpha) < 0.0001 {
      if alpha > 0.001, !suppressOrderFront {
        panel.orderFrontRegardless()
      } else if alpha <= 0.001 {
        panel.orderOut(nil)
      }
      return
    }

    if alpha > 0.001, !suppressOrderFront {
      panel.orderFrontRegardless()
    }

    if animated {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = Self.settleAnimationDuration
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        shadeView.animator().alphaValue = alpha
      } completionHandler: { [weak self] in
        Task { @MainActor in
          guard let self,
            !self.hasTornDown,
            generation == self.animationGeneration
          else {
            return
          }
          if self.currentBrightness >= 0.999 {
            self.panel?.orderOut(nil)
          }
        }
      }
    } else {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      shadeView.alphaValue = alpha
      CATransaction.commit()
      if alpha <= 0.001 {
        panel.orderOut(nil)
      }
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
