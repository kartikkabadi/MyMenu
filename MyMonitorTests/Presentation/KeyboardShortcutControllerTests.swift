import XCTest
@testable import MyMonitorPresentation

@MainActor
final class KeyboardShortcutControllerTests: XCTestCase {
  func testLoadsAndRegistersPersistedConfiguration() {
    let configuration = KeyboardShortcutConfiguration(
      decreaseShortcut: decreaseShortcut,
      increaseShortcut: increaseShortcut,
      target: .allExternalDisplays
    )
    let service = FakeGlobalHotKeyService()
    let persistence = FakeKeyboardShortcutPersistence(configuration: configuration)

    let controller = KeyboardShortcutController(
      service: service,
      persistence: persistence
    )

    XCTAssertEqual(controller.configuration, configuration)
    XCTAssertEqual(service.registrations, configuration.registrations)
  }

  func testShortcutRequiresModifier() {
    let service = FakeGlobalHotKeyService()
    let persistence = FakeKeyboardShortcutPersistence(configuration: .empty)
    let controller = KeyboardShortcutController(service: service, persistence: persistence)
    let invalid = RecordedShortcut(keyCode: 0, modifiers: [], keyDisplay: "A")

    controller.setShortcut(invalid, for: .increaseBrightness)

    XCTAssertEqual(
      controller.errorMessage,
      "Shortcuts must include at least one modifier key."
    )
    XCTAssertNil(controller.shortcut(for: .increaseBrightness))
    XCTAssertEqual(persistence.savedConfigurations.count, 0)
  }

  func testIncreaseAndDecreaseCannotShareShortcut() {
    let initial = KeyboardShortcutConfiguration(
      decreaseShortcut: decreaseShortcut,
      increaseShortcut: nil,
      target: .displayUnderPointer
    )
    let service = FakeGlobalHotKeyService()
    let persistence = FakeKeyboardShortcutPersistence(configuration: initial)
    let controller = KeyboardShortcutController(service: service, persistence: persistence)

    controller.setShortcut(decreaseShortcut, for: .increaseBrightness)

    XCTAssertEqual(
      controller.errorMessage,
      "Increase and decrease brightness cannot use the same shortcut."
    )
    XCTAssertNil(controller.shortcut(for: .increaseBrightness))
  }

  func testRegistrationFailurePreservesConfigurationAndWorkingRegistrations() {
    let initial = KeyboardShortcutConfiguration(
      decreaseShortcut: decreaseShortcut,
      increaseShortcut: nil,
      target: .displayUnderPointer
    )
    let service = FakeGlobalHotKeyService()
    let persistence = FakeKeyboardShortcutPersistence(configuration: initial)
    let controller = KeyboardShortcutController(service: service, persistence: persistence)
    service.clearsRegistrationsBeforeThrow = true
    service.nextError = TestError.unavailable

    controller.setShortcut(increaseShortcut, for: .increaseBrightness)

    XCTAssertEqual(controller.configuration, initial)
    XCTAssertEqual(controller.errorMessage, TestError.unavailable.localizedDescription)
    XCTAssertEqual(service.registrations, initial.registrations)
    XCTAssertTrue(persistence.savedConfigurations.isEmpty)
  }

  func testSuccessfulShortcutReplacementPersistsAndRegistersAtomically() {
    let service = FakeGlobalHotKeyService()
    let persistence = FakeKeyboardShortcutPersistence(configuration: .empty)
    let controller = KeyboardShortcutController(service: service, persistence: persistence)

    controller.setShortcut(increaseShortcut, for: .increaseBrightness)

    XCTAssertEqual(controller.shortcut(for: .increaseBrightness), increaseShortcut)
    XCTAssertEqual(
      service.registrations,
      [
        GlobalHotKeyRegistration(
          action: .increaseBrightness,
          shortcut: increaseShortcut
        ),
      ]
    )
    XCTAssertEqual(persistence.savedConfigurations.last, controller.configuration)
  }

  func testClearingShortcutUnregistersIt() {
    let initial = KeyboardShortcutConfiguration(
      decreaseShortcut: decreaseShortcut,
      increaseShortcut: increaseShortcut,
      target: .displayUnderPointer
    )
    let service = FakeGlobalHotKeyService()
    let persistence = FakeKeyboardShortcutPersistence(configuration: initial)
    let controller = KeyboardShortcutController(service: service, persistence: persistence)

    controller.setShortcut(nil, for: .decreaseBrightness)

    XCTAssertNil(controller.shortcut(for: .decreaseBrightness))
    XCTAssertEqual(
      service.registrations,
      [
        GlobalHotKeyRegistration(
          action: .increaseBrightness,
          shortcut: increaseShortcut
        ),
      ]
    )
  }

  func testActionUsesLatestPersistedTarget() {
    let service = FakeGlobalHotKeyService()
    let persistence = FakeKeyboardShortcutPersistence(configuration: .empty)
    let controller = KeyboardShortcutController(service: service, persistence: persistence)
    let monitorID = MonitorID(rawValue: 88)
    var received: (KeyboardShortcutAction, KeyboardBrightnessTarget)?
    controller.actionHandler = { action, target in
      received = (action, target)
    }

    controller.setTarget(.display(monitorID))
    service.fire(.increaseBrightness)

    XCTAssertEqual(received?.0, .increaseBrightness)
    XCTAssertEqual(received?.1, .display(monitorID))
    XCTAssertEqual(persistence.savedConfigurations.last?.target, .display(monitorID))
  }

  func testForgettingSelectedDisplayTargetFallsBackToPointerAndPersists() {
    let monitorID = MonitorID(rawValue: 88)
    let initial = KeyboardShortcutConfiguration(
      decreaseShortcut: decreaseShortcut,
      increaseShortcut: increaseShortcut,
      target: .display(monitorID)
    )
    let service = FakeGlobalHotKeyService()
    let persistence = FakeKeyboardShortcutPersistence(configuration: initial)
    let controller = KeyboardShortcutController(service: service, persistence: persistence)

    controller.forgetDisplayTarget(monitorID)

    XCTAssertEqual(controller.configuration.target, .displayUnderPointer)
    XCTAssertEqual(persistence.savedConfigurations.last?.target, .displayUnderPointer)
    XCTAssertEqual(service.registrations, initial.registrations)
  }

  func testShortcutDisplayUsesMacModifierGlyphs() {
    let shortcut = RecordedShortcut(
      keyCode: 24,
      modifiers: [.control, .option, .shift, .command],
      keyDisplay: "+"
    )

    XCTAssertEqual(shortcut.displayText, "⌃⌥⇧⌘+")
  }

  private let decreaseShortcut = RecordedShortcut(
    keyCode: 27,
    modifiers: [.control, .option],
    keyDisplay: "−"
  )

  private let increaseShortcut = RecordedShortcut(
    keyCode: 24,
    modifiers: [.control, .option],
    keyDisplay: "+"
  )
}

@MainActor
final class DisplayPresentationKeyboardTests: XCTestCase {
  func testKeyboardStepClampsAndPersistsAtMonitorMaximum() {
    let monitorID = MonitorID(rawValue: 42)
    let controller = FakeKeyboardMonitorController(
      snapshot: .ready([
        MonitorSnapshot(
          id: monitorID,
          name: "Display",
          brightness: 0.78,
          allowedRange: 0.2...0.8,
          control: .available(.hardware)
        ),
      ])
    )
    let store = DisplayPresentationStore(controller: controller)

    store.adjustBrightness(by: 0.05, for: monitorID)

    XCTAssertEqual(store.monitor(withID: monitorID)?.brightness, 0.8)
    XCTAssertEqual(
      controller.writes,
      [
        KeyboardBrightnessWrite(
          value: 0.8,
          monitorID: monitorID,
          animated: false,
          persist: false
        ),
        KeyboardBrightnessWrite(
          value: 0.8,
          monitorID: monitorID,
          animated: true,
          persist: true
        ),
      ]
    )
  }
}

@MainActor
private final class FakeGlobalHotKeyService: GlobalHotKeyServing {
  private(set) var registrations: [GlobalHotKeyRegistration] = []
  private var handler: (@MainActor (KeyboardShortcutAction) -> Void)?
  var nextError: Error?
  var clearsRegistrationsBeforeThrow = false

  func replaceRegistrations(
    _ registrations: [GlobalHotKeyRegistration],
    handler: @escaping @MainActor (KeyboardShortcutAction) -> Void
  ) throws {
    if let nextError {
      self.nextError = nil
      if clearsRegistrationsBeforeThrow {
        self.registrations = []
        self.handler = nil
      }
      throw nextError
    }
    self.registrations = registrations
    self.handler = handler
  }

  func unregisterAll() {
    registrations = []
    handler = nil
  }

  func fire(_ action: KeyboardShortcutAction) {
    handler?(action)
  }
}

@MainActor
private final class FakeKeyboardShortcutPersistence: KeyboardShortcutPersisting {
  private let initialConfiguration: KeyboardShortcutConfiguration
  private(set) var savedConfigurations: [KeyboardShortcutConfiguration] = []

  init(configuration: KeyboardShortcutConfiguration) {
    initialConfiguration = configuration
  }

  func loadConfiguration() -> KeyboardShortcutConfiguration {
    initialConfiguration
  }

  func saveConfiguration(_ configuration: KeyboardShortcutConfiguration) {
    savedConfigurations.append(configuration)
  }
}

@MainActor
private final class FakeKeyboardMonitorController: MonitorControlling {
  private(set) var currentSnapshot: DisplayControllerSnapshot
  private var handler: (@MainActor (DisplayControllerSnapshot) -> Void)?
  private(set) var writes: [KeyboardBrightnessWrite] = []

  init(snapshot: DisplayControllerSnapshot) {
    currentSnapshot = snapshot
  }

  func setSnapshotHandler(
    _ handler: @escaping @MainActor (DisplayControllerSnapshot) -> Void
  ) {
    self.handler = handler
  }

  func refresh() {}

  func setBrightness(
    _ value: Double,
    for monitorID: MonitorID,
    animated: Bool,
    persist: Bool
  ) {
    writes.append(
      KeyboardBrightnessWrite(
        value: value,
        monitorID: monitorID,
        animated: animated,
        persist: persist
      )
    )
  }

  func retryControl(for monitorID: MonitorID) {}
  func teardown() {}
}

private struct KeyboardBrightnessWrite: Equatable {
  let value: Double
  let monitorID: MonitorID
  let animated: Bool
  let persist: Bool
}

private enum TestError: LocalizedError {
  case unavailable

  var errorDescription: String? {
    "Shortcut unavailable"
  }
}
