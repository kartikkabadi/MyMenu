import AppKit
import CoreGraphics
import Foundation

@MainActor
final class KeyboardBrightnessCoordinator {
  private let store: DisplayPresentationStore
  private let configurationStore: DisplayConfigurationStore

  init(
    store: DisplayPresentationStore,
    configurationStore: DisplayConfigurationStore
  ) {
    self.store = store
    self.configurationStore = configurationStore
  }

  func perform(
    _ action: KeyboardShortcutAction,
    target: KeyboardBrightnessTarget
  ) {
    for monitorID in monitorIDs(for: target) {
      store.adjustBrightness(by: action.delta, for: monitorID)
    }
  }

  private func monitorIDs(for target: KeyboardBrightnessTarget) -> [MonitorID] {
    switch target {
    case .allExternalDisplays:
      return controllableMonitorIDs

    case .display(let monitorID):
      if store.monitor(withID: monitorID)?.brightness != nil {
        return [monitorID]
      }

      // A full mirror collapses multiple connected physical displays into one presentation row.
      // Preserve an explicit still-connected target by routing it through that representative; the
      // router then fans the brightness value out to every external member of the mirror set.
      let connectedIDs = configurationStore.configurations
        .filter(\.isConnected)
        .map(\.id)
      guard connectedIDs.contains(monitorID),
        connectedIDs.count > controllableMonitorIDs.count
      else {
        return []
      }
      return controllableMonitorIDs.first.map { [$0] } ?? []

    case .displayUnderPointer:
      if let monitorID = externalMonitorUnderPointer() {
        return [monitorID]
      }
      return controllableMonitorIDs.first.map { [$0] } ?? []
    }
  }

  private var controllableMonitorIDs: [MonitorID] {
    store.monitors.compactMap { monitor in
      monitor.brightness == nil ? nil : monitor.id
    }
  }

  private func externalMonitorUnderPointer() -> MonitorID? {
    let pointerLocation = NSEvent.mouseLocation
    guard let screen = NSScreen.screens.first(where: { screen in
      NSMouseInRect(pointerLocation, screen.frame, false)
    }) else {
      return nil
    }

    let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
    guard let number = screen.deviceDescription[screenNumberKey] as? NSNumber else {
      return nil
    }

    let monitorID = MonitorID(rawValue: CGDirectDisplayID(number.uint32Value))
    guard store.monitor(withID: monitorID)?.brightness != nil else { return nil }
    return monitorID
  }
}
