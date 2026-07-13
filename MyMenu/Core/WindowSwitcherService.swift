import ApplicationServices
import Carbon
import Cocoa
import SwiftUI

/// Provides an Option-Tab window switcher with a lightweight floating HUD.
@MainActor
final class WindowSwitcherService: ObservableObject {
  static let shared = WindowSwitcherService()

  @Published private(set) var windows: [WindowItem] = []
  @Published private(set) var selectedIndex = 0

  private var eventHandler: EventHandlerRef?
  private var isRegistered = false
  private var isShowing = false
  private var hudPanel: NSPanel?
  private var hotKeyRefNormal: EventHotKeyRef?
  private var hotKeyRefReverse: EventHotKeyRef?
  private var flagsMonitor: Any?
  private var localFlagsMonitor: Any?

  private init() {}

  func start() {
    guard AppPreferences.isWindowSwitcherEnabled else { return }
    registerHotKeys()
  }

  func stop() {
    unregisterHotKeys()
    dismissHUD()
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
          WindowSwitcherService.shared.handleHotKey(id: id)
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

    let definitions: [(UInt32, UInt32, UInt32)] = [
      (48, UInt32(optionKey), 101),
      (48, UInt32(optionKey | shiftKey), 102),
    ]

    for (keyCode, modifiers, id) in definitions {
      var hotKey: EventHotKeyRef?
      let status = RegisterEventHotKey(
        keyCode,
        modifiers,
        EventHotKeyID(signature: 5678, id: id),
        GetApplicationEventTarget(),
        0,
        &hotKey
      )

      guard status == noErr, let hotKey else {
        if let hotKeyRefNormal {
          UnregisterEventHotKey(hotKeyRefNormal)
          self.hotKeyRefNormal = nil
        }
        if let hotKeyRefReverse {
          UnregisterEventHotKey(hotKeyRefReverse)
          self.hotKeyRefReverse = nil
        }
        RemoveEventHandler(handler)
        eventHandler = nil
        return
      }

      if id == 101 {
        hotKeyRefNormal = hotKey
      } else {
        hotKeyRefReverse = hotKey
      }
    }

    isRegistered = true
  }

  private func unregisterHotKeys() {
    if let hotKeyRefNormal {
      UnregisterEventHotKey(hotKeyRefNormal)
      self.hotKeyRefNormal = nil
    }
    if let hotKeyRefReverse {
      UnregisterEventHotKey(hotKeyRefReverse)
      self.hotKeyRefReverse = nil
    }
    isRegistered = false

    if let eventHandler {
      RemoveEventHandler(eventHandler)
      self.eventHandler = nil
    }
  }

  private func handleHotKey(id: UInt32) {
    if !isShowing {
      guard PermissionManager.shared.hasScreenRecordingAccess else {
        PermissionManager.shared.requestScreenRecordingAccess()
        return
      }

      guard PermissionManager.shared.hasAccessibilityAccess else {
        PermissionManager.shared.requestAccessibilityAccess()
        return
      }

      windows = getWindowList()
      guard !windows.isEmpty else { return }

      selectedIndex = windows.count > 1 ? 1 : 0
      isShowing = true
      showHUD()
      startFlagsMonitor()
      return
    }

    guard !windows.isEmpty else {
      dismissHUD()
      return
    }

    if id == 101 {
      selectedIndex = (selectedIndex + 1) % windows.count
    } else if id == 102 {
      selectedIndex = (selectedIndex - 1 + windows.count) % windows.count
    }
  }

  private func showHUD() {
    guard hudPanel == nil else { return }

    let view = WindowSwitcherHUDView(service: self)
    let host = NSHostingController(rootView: view)
    host.view.wantsLayer = true
    host.view.layer?.backgroundColor = .clear

    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 550, height: 380),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.level = .statusBar
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.ignoresMouseEvents = false
    panel.isMovable = false
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    panel.contentView = host.view
    panel.center()
    panel.orderFrontRegardless()

    hudPanel = panel
  }

  private func dismissHUD() {
    hudPanel?.orderOut(nil)
    hudPanel = nil
    isShowing = false
    stopFlagsMonitor()
  }

  private func finishSwitching() {
    guard isShowing else { return }

    let targetIndex = selectedIndex
    let selectedWindow = windows.indices.contains(targetIndex) ? windows[targetIndex] : nil
    dismissHUD()
    guard let selectedWindow else { return }

    guard let app = NSRunningApplication(processIdentifier: selectedWindow.ownerPID) else { return }
    app.activate(options: [.activateAllWindows])

    let appElement = AXUIElementCreateApplication(selectedWindow.ownerPID)
    var windowListValue: AnyObject?
    guard AXUIElementCopyAttributeValue(
      appElement,
      kAXWindowsAttribute as CFString,
      &windowListValue
    ) == .success,
    let appWindows = windowListValue as? [AXUIElement]
    else {
      return
    }

    for window in appWindows {
      var titleValue: AnyObject?
      AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
      let title = titleValue as? String ?? ""
      let matchesTitle = title == selectedWindow.windowName
        || (selectedWindow.windowName == "Untitled Window" && title.isEmpty)
      guard matchesTitle else { continue }

      AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
      AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
      break
    }
  }

  private func startFlagsMonitor() {
    flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
      guard !event.modifierFlags.contains(.option) else { return }
      Task { @MainActor in self?.finishSwitching() }
    }

    localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
      if !event.modifierFlags.contains(.option) {
        Task { @MainActor in self?.finishSwitching() }
      }
      return event
    }
  }

  private func stopFlagsMonitor() {
    if let flagsMonitor {
      NSEvent.removeMonitor(flagsMonitor)
      self.flagsMonitor = nil
    }
    if let localFlagsMonitor {
      NSEvent.removeMonitor(localFlagsMonitor)
      self.localFlagsMonitor = nil
    }
  }

  private func getWindowList() -> [WindowItem] {
    let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
    guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: AnyObject]] else {
      return []
    }

    let excludedOwners = Set([
      "ControlCenter",
      "Dock",
      "loginwindow",
      "NotificationCenter",
      "SystemUIServer",
      "Window Server",
    ])
    let ownPID = ProcessInfo.processInfo.processIdentifier

    return list.compactMap { info in
      guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
            let ownerPID = info[kCGWindowOwnerPID as String] as? Int32,
            ownerPID != ownPID
      else {
        return nil
      }

      let ownerName = (info[kCGWindowOwnerName as String] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      guard !ownerName.isEmpty, !excludedOwners.contains(ownerName) else { return nil }
      if ownerName == "Finder", (info[kCGWindowName as String] as? String) == "Desktop" { return nil }

      guard let boundsDictionary = info[kCGWindowBounds as String] as? [String: AnyObject],
            let width = (boundsDictionary["Width"] as? NSNumber)?.doubleValue,
            let height = (boundsDictionary["Height"] as? NSNumber)?.doubleValue,
            width > 120,
            height > 120
      else {
        return nil
      }

      let bounds = CGRect(
        x: (boundsDictionary["X"] as? NSNumber)?.doubleValue ?? 0,
        y: (boundsDictionary["Y"] as? NSNumber)?.doubleValue ?? 0,
        width: width,
        height: height
      )
      let title = (info[kCGWindowName as String] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

      return WindowItem(
        id: (info[kCGWindowNumber as String] as? CGWindowID) ?? 0,
        ownerPID: ownerPID,
        ownerName: ownerName,
        windowName: title.isEmpty ? "Untitled Window" : title,
        bounds: bounds,
        appIcon: NSRunningApplication(processIdentifier: ownerPID)?.icon
      )
    }
  }
}
