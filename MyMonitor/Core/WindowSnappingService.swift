import ApplicationServices
import Carbon
import Cocoa

/// Handles Control-Option arrow shortcuts and resizes the focused window.
@MainActor
final class WindowSnappingService {
  static let shared = WindowSnappingService()

  private var eventHandler: EventHandlerRef?
  private var hotKeys: [EventHotKeyRef] = []
  private var isRegistered = false

  // Store original AppKit frames so pressing the same shortcut restores the window.
  private var savedFrames: [String: CGRect] = [:]

  func start() {
    guard AppPreferences.isWindowSnappingEnabled else { return }
    registerHotKeys()
  }

  func stop() {
    unregisterHotKeys()
    savedFrames.removeAll()
  }

  private func registerHotKeys() {
    guard !isRegistered else { return }

    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )

    var handler: EventHandlerRef?
    let handlerStatus = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, _ -> OSStatus in
        guard let event else { return OSStatus(eventNotHandledErr) }

        var hotKeyID = EventHotKeyID()
        let result = GetEventParameter(
          event,
          EventParamName(kEventParamDirectObject),
          EventParamType(typeEventHotKeyID),
          nil,
          MemoryLayout<EventHotKeyID>.size,
          nil,
          &hotKeyID
        )

        guard result == noErr else { return OSStatus(eventNotHandledErr) }
        let id = hotKeyID.id
        Task { @MainActor in
          WindowSnappingService.shared.handleHotKey(id: id)
        }
        return noErr
      },
      1,
      &eventType,
      nil,
      &handler
    )

    guard handlerStatus == noErr, let handler else { return }
    eventHandler = handler

    let flags = UInt32(controlKey | optionKey)
    let definitions: [(UInt32, UInt32)] = [
      (123, 1), // Left arrow
      (124, 2), // Right arrow
      (126, 3), // Up arrow
      (125, 4), // Down arrow
    ]

    var registered: [EventHotKeyRef] = []
    for (keyCode, id) in definitions {
      var hotKey: EventHotKeyRef?
      let status = RegisterEventHotKey(
        keyCode,
        flags,
        EventHotKeyID(signature: 1234, id: id),
        GetApplicationEventTarget(),
        0,
        &hotKey
      )

      guard status == noErr, let hotKey else {
        registered.forEach { UnregisterEventHotKey($0) }
        RemoveEventHandler(handler)
        eventHandler = nil
        return
      }
      registered.append(hotKey)
    }

    hotKeys = registered
    isRegistered = true
  }

  private func unregisterHotKeys() {
    hotKeys.forEach { UnregisterEventHotKey($0) }
    hotKeys.removeAll()
    isRegistered = false

    if let eventHandler {
      RemoveEventHandler(eventHandler)
      self.eventHandler = nil
    }
  }

  func handleHotKey(id: UInt32) {
    guard PermissionManager.shared.hasAccessibilityAccess else { return }
    guard let frontmostApp = NSWorkspace.shared.frontmostApplication else { return }

    let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
    var windowValue: AnyObject?
    let windowStatus = AXUIElementCopyAttributeValue(
      appElement,
      kAXFocusedWindowAttribute as CFString,
      &windowValue
    )
    guard windowStatus == .success,
          let windowValue,
          CFGetTypeID(windowValue) == AXUIElementGetTypeID()
    else {
      return
    }
    let window = windowValue as! AXUIElement

    guard let windowPosition = pointValue(for: window, attribute: kAXPositionAttribute as CFString),
          let windowSize = sizeValue(for: window, attribute: kAXSizeAttribute as CFString)
    else {
      return
    }

    let desktopTop = NSScreen.screens.first?.frame.maxY ?? 0
    let accessibilityFrame = CGRect(origin: windowPosition, size: windowSize)
    let appKitFrame = accessibilityToAppKit(accessibilityFrame, desktopTop: desktopTop)
    let targetScreen = NSScreen.screens.first(where: { $0.frame.intersects(appKitFrame) })
      ?? NSScreen.main
      ?? NSScreen.screens.first
    guard let targetScreen else { return }

    let visibleFrame = targetScreen.visibleFrame
    let margin: CGFloat = 8
    let targetRect: CGRect

    switch id {
    case 1:
      let halfWidth = visibleFrame.width / 2
      targetRect = CGRect(
        x: visibleFrame.minX + margin,
        y: visibleFrame.minY + margin,
        width: halfWidth - (margin * 1.5),
        height: visibleFrame.height - (margin * 2)
      )
    case 2:
      let halfWidth = visibleFrame.width / 2
      targetRect = CGRect(
        x: visibleFrame.minX + halfWidth + (margin * 0.5),
        y: visibleFrame.minY + margin,
        width: halfWidth - (margin * 1.5),
        height: visibleFrame.height - (margin * 2)
      )
    case 3:
      targetRect = CGRect(
        x: visibleFrame.minX + margin,
        y: visibleFrame.minY + margin,
        width: visibleFrame.width - (margin * 2),
        height: visibleFrame.height - (margin * 2)
      )
    case 4:
      let width = min(visibleFrame.width * 0.72, 1280)
      let height = min(visibleFrame.height * 0.72, 820)
      targetRect = CGRect(
        x: visibleFrame.minX + (visibleFrame.width - width) / 2,
        y: visibleFrame.minY + (visibleFrame.height - height) / 2,
        width: width,
        height: height
      )
    default:
      return
    }

    var titleValue: AnyObject?
    let title = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success
      ? (titleValue as? String ?? "")
      : ""
    let windowKey = "\(frontmostApp.bundleIdentifier ?? "")-\(title)"
    let targetAccessibilityFrame = appKitToAccessibility(targetRect, desktopTop: desktopTop)

    if framesMatch(accessibilityFrame, targetAccessibilityFrame),
       let savedFrame = savedFrames[windowKey] {
      _ = setFrame(savedFrame, on: window, desktopTop: desktopTop)
      savedFrames.removeValue(forKey: windowKey)
      return
    }

    savedFrames[windowKey] = appKitFrame
    _ = setFrame(targetRect, on: window, desktopTop: desktopTop)
  }

  private func pointValue(for window: AXUIElement, attribute: CFString) -> CGPoint? {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(window, attribute, &value) == .success,
          CFGetTypeID(value) == AXValueGetTypeID()
    else {
      return nil
    }

    let axValue = value as! AXValue
    guard AXValueGetType(axValue) == .cgPoint else { return nil }
    var point = CGPoint.zero
    return AXValueGetValue(axValue, .cgPoint, &point) ? point : nil
  }

  private func sizeValue(for window: AXUIElement, attribute: CFString) -> CGSize? {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(window, attribute, &value) == .success,
          CFGetTypeID(value) == AXValueGetTypeID()
    else {
      return nil
    }

    let axValue = value as! AXValue
    guard AXValueGetType(axValue) == .cgSize else { return nil }
    var size = CGSize.zero
    return AXValueGetValue(axValue, .cgSize, &size) ? size : nil
  }

  private func appKitToAccessibility(_ rect: CGRect, desktopTop: CGFloat) -> CGRect {
    CGRect(
      x: rect.origin.x,
      y: desktopTop - rect.maxY,
      width: rect.width,
      height: rect.height
    )
  }

  private func accessibilityToAppKit(_ rect: CGRect, desktopTop: CGFloat) -> CGRect {
    CGRect(
      x: rect.origin.x,
      y: desktopTop - rect.maxY,
      width: rect.width,
      height: rect.height
    )
  }

  private func framesMatch(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
    abs(lhs.origin.x - rhs.origin.x) < 5
      && abs(lhs.origin.y - rhs.origin.y) < 5
      && abs(lhs.width - rhs.width) < 5
      && abs(lhs.height - rhs.height) < 5
  }

  @discardableResult
  private func setFrame(_ appKitFrame: CGRect, on window: AXUIElement, desktopTop: CGFloat) -> Bool {
    let accessibilityFrame = appKitToAccessibility(appKitFrame, desktopTop: desktopTop)
    var position = accessibilityFrame.origin
    var size = accessibilityFrame.size

    guard let positionValue = AXValueCreate(.cgPoint, &position),
          let sizeValue = AXValueCreate(.cgSize, &size)
    else {
      return false
    }

    let sizeStatus = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
    let positionStatus = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
    return sizeStatus == .success && positionStatus == .success
  }
}
