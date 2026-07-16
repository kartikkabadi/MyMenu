#if DEBUG
import SwiftUI

@MainActor
private func previewPopover(
  _ snapshot: DisplayControllerSnapshot
) -> some View {
  let controller = PreviewFrontendController(snapshot: snapshot)
  let store = DisplayPresentationStore(controller: controller)
  return BrightnessPopoverView(store: store)
}

@MainActor
private func previewSettings(
  destination: SettingsDestination,
  snapshot: DisplayControllerSnapshot = MonitorPresentationFixtures.twoMixedDisplays
) -> some View {
  let controller = PreviewFrontendController(snapshot: snapshot)
  let presentationStore = DisplayPresentationStore(controller: controller)
  let configurationStore = DisplayConfigurationStore(controller: controller)
  let launchAtLoginController = LaunchAtLoginController(
    service: PreviewLaunchAtLoginService()
  )
  let keyboardShortcutController = KeyboardShortcutController(
    service: PreviewGlobalHotKeyService(),
    persistence: PreviewKeyboardShortcutPersistence()
  )
  let navigationModel = SettingsNavigationModel()
  navigationModel.selection = destination
  let diagnosticsController = DiagnosticsController(
    presentationStore: presentationStore,
    configurationStore: configurationStore
  )

  return SettingsRootView(
    store: presentationStore,
    configurationStore: configurationStore,
    launchAtLoginController: launchAtLoginController,
    keyboardShortcutController: keyboardShortcutController,
    navigationModel: navigationModel,
    diagnosticsController: diagnosticsController
  )
  .frame(width: 720, height: 500)
}

#Preview("Popover — Detecting") {
  previewPopover(MonitorPresentationFixtures.detectingWithoutCache)
}

#Preview("Popover — Empty") {
  previewPopover(MonitorPresentationFixtures.empty)
}

#Preview("Popover — One Hardware Display") {
  previewPopover(MonitorPresentationFixtures.oneHardwareDisplay)
}

#Preview("Popover — Two Mixed Displays") {
  previewPopover(MonitorPresentationFixtures.twoMixedDisplays)
}

#Preview("Popover — Checking Control") {
  previewPopover(MonitorPresentationFixtures.checkingControl)
}

#Preview("Popover — Unavailable Control") {
  previewPopover(MonitorPresentationFixtures.unavailableControl)
}

#Preview("Popover — Failure") {
  previewPopover(MonitorPresentationFixtures.failed)
}

#Preview("Popover — Long Display Name") {
  previewPopover(MonitorPresentationFixtures.longNameDisplay)
}

#Preview("Popover — Four Displays") {
  previewPopover(MonitorPresentationFixtures.fourDisplays)
}

#Preview("Popover — Eight Displays") {
  previewPopover(MonitorPresentationFixtures.eightDisplays)
}

#Preview("Popover — Two Displays — Dark") {
  previewPopover(MonitorPresentationFixtures.twoMixedDisplays)
    .preferredColorScheme(.dark)
}

#Preview("Settings — General") {
  previewSettings(destination: .general)
}

#Preview("Settings — Displays") {
  previewSettings(destination: .displays)
}

#Preview("Settings — Keyboard") {
  previewSettings(destination: .keyboard)
}

#Preview("Settings — Advanced") {
  previewSettings(destination: .advanced)
}

#Preview("Settings — About") {
  previewSettings(destination: .about)
}

#Preview("Settings — Dark") {
  previewSettings(destination: .displays)
    .preferredColorScheme(.dark)
}

@MainActor
private final class PreviewFrontendController:
  MonitorControlling,
  DisplayConfigurationControlling
{
  private(set) var currentSnapshot: DisplayControllerSnapshot
  private(set) var currentConfigurations: [MonitorConfigurationSnapshot]

  private var snapshotHandler: (@MainActor (DisplayControllerSnapshot) -> Void)?
  private var configurationHandler: (@MainActor ([MonitorConfigurationSnapshot]) -> Void)?

  init(snapshot: DisplayControllerSnapshot) {
    currentSnapshot = snapshot
    currentConfigurations = Self.configurations(from: snapshot)
  }

  func setSnapshotHandler(
    _ handler: @escaping @MainActor (DisplayControllerSnapshot) -> Void
  ) {
    snapshotHandler = handler
  }

  func setConfigurationHandler(
    _ handler: @escaping @MainActor ([MonitorConfigurationSnapshot]) -> Void
  ) {
    configurationHandler = handler
  }

  func refresh() {}

  func setBrightness(
    _ value: Double,
    for monitorID: MonitorID,
    animated: Bool,
    persist: Bool
  ) {
    _ = animated
    _ = persist
    mutateSnapshot(for: monitorID) { snapshot in
      snapshot.brightness = value
    }
  }

  func retryControl(for monitorID: MonitorID) {
    mutateSnapshot(for: monitorID) { snapshot in
      snapshot.control = .checking
    }
  }

  func setBrightnessRange(
    _ range: ClosedRange<Double>,
    for monitorID: MonitorID
  ) {
    guard let index = currentConfigurations.firstIndex(where: { $0.id == monitorID }) else {
      return
    }
    currentConfigurations[index].allowedRange = range
    configurationHandler?(currentConfigurations)
  }

  func setControlPreference(
    _ preference: MonitorControlPreference,
    for monitorID: MonitorID
  ) {
    guard let index = currentConfigurations.firstIndex(where: { $0.id == monitorID }) else {
      return
    }
    currentConfigurations[index].preference = preference
    configurationHandler?(currentConfigurations)
  }

  func forgetConfiguration(for monitorID: MonitorID) {
    currentConfigurations.removeAll { $0.id == monitorID }
    configurationHandler?(currentConfigurations)
  }

  func teardown() {}

  private func mutateSnapshot(
    for monitorID: MonitorID,
    mutation: (inout MonitorSnapshot) -> Void
  ) {
    guard case .ready(var snapshots) = currentSnapshot,
      let index = snapshots.firstIndex(where: { $0.id == monitorID })
    else {
      return
    }

    mutation(&snapshots[index])
    currentSnapshot = .ready(snapshots)
    currentConfigurations = Self.configurations(from: currentSnapshot)
    snapshotHandler?(currentSnapshot)
    configurationHandler?(currentConfigurations)
  }

  private static func configurations(
    from snapshot: DisplayControllerSnapshot
  ) -> [MonitorConfigurationSnapshot] {
    let snapshots: [MonitorSnapshot]
    switch snapshot {
    case .detecting(let cached), .ready(let cached):
      snapshots = cached
    case .failed:
      snapshots = []
    }

    return snapshots.map { monitor in
      MonitorConfigurationSnapshot(
        id: monitor.id,
        name: monitor.name,
        isConnected: true,
        brightness: monitor.brightness,
        allowedRange: monitor.allowedRange,
        preference: .automatic,
        activeMethod: monitor.control.activeMethod
      )
    }
  }
}

private extension MonitorControlState {
  var activeMethod: MonitorControlMethod? {
    guard case .available(let method) = self else { return nil }
    return method
  }
}

@MainActor
private final class PreviewLaunchAtLoginService: LaunchAtLoginServicing {
  var status: LaunchAtLoginServiceStatus = .notRegistered

  func register() throws {
    status = .enabled
  }

  func unregister() throws {
    status = .notRegistered
  }
}

@MainActor
private final class PreviewGlobalHotKeyService: GlobalHotKeyServing {
  func replaceRegistrations(
    _ registrations: [GlobalHotKeyRegistration],
    handler: @escaping @MainActor (KeyboardShortcutAction) -> Void
  ) throws {
    _ = registrations
    _ = handler
  }

  func unregisterAll() {}
}

@MainActor
private final class PreviewKeyboardShortcutPersistence: KeyboardShortcutPersisting {
  func loadConfiguration() -> KeyboardShortcutConfiguration {
    .empty
  }

  func saveConfiguration(_ configuration: KeyboardShortcutConfiguration) {
    _ = configuration
  }
}
#endif
