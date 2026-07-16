import Carbon
import Foundation

private func myMonitorGlobalHotKeyHandler(
  _ nextHandler: EventHandlerCallRef?,
  _ event: EventRef?,
  _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
  _ = nextHandler
  guard let event, let userData else { return OSStatus(eventNotHandledErr) }

  var hotKeyID = EventHotKeyID(signature: 0, id: 0)
  let status = GetEventParameter(
    event,
    EventParamName(kEventParamDirectObject),
    EventParamType(typeEventHotKeyID),
    nil,
    MemoryLayout<EventHotKeyID>.size,
    nil,
    &hotKeyID
  )
  guard status == noErr else { return status }

  let service = Unmanaged<CarbonGlobalHotKeyService>
    .fromOpaque(userData)
    .takeUnretainedValue()
  Task { @MainActor in
    service.handleHotKey(id: hotKeyID.id)
  }
  return noErr
}

@MainActor
final class CarbonGlobalHotKeyService: GlobalHotKeyServing {
  private static let signature: OSType = 0x4D794D6F // 'MyMo'

  private var eventHandler: EventHandlerRef?
  private var installationStatus: OSStatus = noErr
  private var hotKeyReferences: [EventHotKeyRef] = []
  private var actionsByID: [UInt32: KeyboardShortcutAction] = [:]
  private var actionHandler: (@MainActor (KeyboardShortcutAction) -> Void)?

  init() {
    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )
    installationStatus = InstallEventHandler(
      GetApplicationEventTarget(),
      myMonitorGlobalHotKeyHandler,
      1,
      &eventType,
      Unmanaged.passUnretained(self).toOpaque(),
      &eventHandler
    )
  }

  deinit {
    for reference in hotKeyReferences {
      UnregisterEventHotKey(reference)
    }
    if let eventHandler {
      RemoveEventHandler(eventHandler)
    }
  }

  func replaceRegistrations(
    _ registrations: [GlobalHotKeyRegistration],
    handler: @escaping @MainActor (KeyboardShortcutAction) -> Void
  ) throws {
    guard installationStatus == noErr else {
      throw GlobalHotKeyRegistrationError(
        message: "MyMonitor could not initialize global keyboard shortcuts.",
        status: installationStatus
      )
    }

    unregisterAll()
    actionHandler = handler

    for registration in registrations {
      var reference: EventHotKeyRef?
      let hotKeyID = EventHotKeyID(
        signature: Self.signature,
        id: registration.action.rawValue
      )
      let status = RegisterEventHotKey(
        registration.shortcut.keyCode,
        registration.shortcut.modifiers.carbonFlags,
        hotKeyID,
        GetApplicationEventTarget(),
        0,
        &reference
      )

      guard status == noErr, let reference else {
        unregisterAll()
        throw GlobalHotKeyRegistrationError(
          message: "That shortcut is unavailable. It may already be used by macOS or another app.",
          status: status
        )
      }

      hotKeyReferences.append(reference)
      actionsByID[registration.action.rawValue] = registration.action
    }
  }

  func unregisterAll() {
    for reference in hotKeyReferences {
      UnregisterEventHotKey(reference)
    }
    hotKeyReferences.removeAll()
    actionsByID.removeAll()
  }

  fileprivate func handleHotKey(id: UInt32) {
    guard let action = actionsByID[id] else { return }
    actionHandler?(action)
  }
}

private extension ShortcutModifiers {
  var carbonFlags: UInt32 {
    var flags: UInt32 = 0
    if contains(.command) { flags |= UInt32(cmdKey) }
    if contains(.option) { flags |= UInt32(optionKey) }
    if contains(.control) { flags |= UInt32(controlKey) }
    if contains(.shift) { flags |= UInt32(shiftKey) }
    return flags
  }
}

private struct GlobalHotKeyRegistrationError: LocalizedError {
  let message: String
  let status: OSStatus

  var errorDescription: String? {
    "\(message) (\(status))"
  }
}
