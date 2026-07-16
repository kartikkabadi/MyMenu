#!/usr/bin/env python3
from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one match, found {count}")
    path.write_text(text.replace(old, new, 1))


router = Path("MyMonitor/Core/DisplayRouter.swift")
contract = Path("scripts/validate_backend_concurrency.sh")

replace_once(
    router,
    """  private var gammaHoldDisplayIDs: Set<CGDirectDisplayID> = []
  private var reconfigurationGeneration: UInt64 = 0
  private let defaults = UserDefaults.standard
""",
    """  private var gammaHoldDisplayIDs: Set<CGDirectDisplayID> = []
  private var reconfigurationGeneration: UInt64 = 0
  private var defaultNotificationObservers: [NSObjectProtocol] = []
  private var workspaceNotificationObservers: [NSObjectProtocol] = []
  private var hasTornDown = false
  private let defaults = UserDefaults.standard
""",
    "router lifetime properties",
)

replace_once(
    router,
    """  private static let preferencesVersion = "v2"
  private static let knownDisplayIDsKey = "MyMonitor.v2.knownDisplayIDs"

  init() {
    registerDisplayCallbacks()
    registerScreenObservers()
    registerWakeObserver()
    registerTerminateObserver()
    reconfigure()
  }
""",
    """  private static let preferencesVersion = "v2"
  private static let knownDisplayIDsKey = "MyMonitor.v2.knownDisplayIDs"
  private static let displayReconfigurationCallback: CGDisplayReconfigurationCallBack = {
    _, flags, userInfo in
    guard let userInfo else { return }
    let router = Unmanaged<DisplayRouter>.fromOpaque(userInfo).takeUnretainedValue()

    if flags.contains(.beginConfigurationFlag) {
      Task { @MainActor in router.scheduleOverlaySpaceSync() }
      return
    }

    if flags.contains(.addFlag) || flags.contains(.removeFlag) {
      Task { @MainActor in router.handleDisplayRoutingChange() }
      return
    }

    // Mirroring and display-mode changes can change the required backend without changing the
    // connected ID set. They must enter the same generation-safe routing path as hot-plug.
    if flags.contains(.desktopShapeChangedFlag) || flags.contains(.setModeFlag) {
      Task { @MainActor in router.handleDisplayRoutingChange() }
      return
    }

    let layoutOnly: CGDisplayChangeSummaryFlags = [.movedFlag, .setMainFlag]
    if flags.isSubset(of: layoutOnly) {
      Task { @MainActor in router.scheduleOverlaySpaceSync() }
    }
  }

  init() {
    registerDisplayCallbacks()
    registerScreenObservers()
    registerWakeObserver()
    reconfigure()
  }
""",
    "static display callback and init",
)

for signature in [
    """  func setBrightness(
    _ value: Double,
    for displayID: CGDirectDisplayID,
    animated: Bool = false,
    persist: Bool = true
  ) {
""",
    """  func setBrightnessRange(
    _ range: ClosedRange<Double>,
    for displayID: CGDirectDisplayID
  ) {
""",
    """  func setControlPreference(
    _ preference: BrightnessControlPreference,
    for displayID: CGDirectDisplayID
  ) {
""",
    """  func forgetDisplayConfiguration(for displayID: CGDirectDisplayID) {
""",
    """  func reconfigure(force: Bool = false) {
""",
]:
    replace_once(
        router,
        signature,
        signature + "    guard !hasTornDown else { return }\n",
        f"teardown guard for {signature.splitlines()[0].strip()}",
    )

replace_once(
    router,
    """  func teardownAll() {
    invalidatePendingReconfiguration()
    teardownInstalledBackends()
  }
""",
    """  func teardownAll() {
    guard !hasTornDown else { return }
    hasTornDown = true

    CGDisplayRemoveReconfigurationCallback(
      Self.displayReconfigurationCallback,
      Unmanaged.passUnretained(self).toOpaque()
    )
    for token in defaultNotificationObservers {
      NotificationCenter.default.removeObserver(token)
    }
    defaultNotificationObservers.removeAll()
    for token in workspaceNotificationObservers {
      NSWorkspace.shared.notificationCenter.removeObserver(token)
    }
    workspaceNotificationObservers.removeAll()

    invalidatePendingReconfiguration()
    teardownInstalledBackends()
  }
""",
    "terminal teardown",
)

replace_once(
    router,
    """  ) {
    guard generation == reconfigurationGeneration else {
      Self.invalidate(ddcResults)
      return
    }
""",
    """  ) {
    guard !hasTornDown, generation == reconfigurationGeneration else {
      Self.invalidate(ddcResults)
      return
    }
""",
    "late reconfiguration result guard",
)

replace_once(
    router,
    """  private func scheduleOverlaySpaceSync() {
    overlayTransitionEndWorkItem?.cancel()
""",
    """  private func scheduleOverlaySpaceSync() {
    guard !hasTornDown else { return }
    overlayTransitionEndWorkItem?.cancel()
""",
    "overlay scheduling teardown guard",
)

old_callback_block = """  private func registerDisplayCallbacks() {
    let callback: CGDisplayReconfigurationCallBack = { _, flags, userInfo in
      guard let userInfo else { return }
      let router = Unmanaged<DisplayRouter>.fromOpaque(userInfo).takeUnretainedValue()

      if flags.contains(.beginConfigurationFlag) {
        Task { @MainActor in router.scheduleOverlaySpaceSync() }
        return
      }

      if flags.contains(.addFlag) || flags.contains(.removeFlag) {
        Task { @MainActor in router.handleDisplayRoutingChange() }
        return
      }

      // Mirroring and display-mode changes can change the required backend without changing the
      // connected ID set. They must enter the same generation-safe routing path as hot-plug.
      if flags.contains(.desktopShapeChangedFlag) || flags.contains(.setModeFlag) {
        Task { @MainActor in router.handleDisplayRoutingChange() }
        return
      }

      let layoutOnly: CGDisplayChangeSummaryFlags = [.movedFlag, .setMainFlag]
      if flags.isSubset(of: layoutOnly) {
        Task { @MainActor in router.scheduleOverlaySpaceSync() }
      }
    }

    let unmanaged = Unmanaged.passUnretained(self)
    CGDisplayRegisterReconfigurationCallback(callback, unmanaged.toOpaque())
  }
"""
new_callback_block = """  private func registerDisplayCallbacks() {
    CGDisplayRegisterReconfigurationCallback(
      Self.displayReconfigurationCallback,
      Unmanaged.passUnretained(self).toOpaque()
    )
  }
"""
replace_once(router, old_callback_block, new_callback_block, "display callback registration")

replace_once(
    router,
    """    NotificationCenter.default.addObserver(
""",
    """    defaultNotificationObservers.append(NotificationCenter.default.addObserver(
""",
    "default screen observer storage",
)
replace_once(
    router,
    """      Task { @MainActor in self?.handleDisplayRoutingChange() }
    }

    NSWorkspace.shared.notificationCenter.addObserver(
""",
    """      Task { @MainActor in self?.handleDisplayRoutingChange() }
    })

    workspaceNotificationObservers.append(NSWorkspace.shared.notificationCenter.addObserver(
""",
    "screen observer closure and workspace storage",
)
replace_once(
    router,
    """      Task { @MainActor in self?.scheduleOverlaySpaceSync() }
    }
  }

  private func registerWakeObserver() {
    NSWorkspace.shared.notificationCenter.addObserver(
""",
    """      Task { @MainActor in self?.scheduleOverlaySpaceSync() }
    })
  }

  private func registerWakeObserver() {
    workspaceNotificationObservers.append(NSWorkspace.shared.notificationCenter.addObserver(
""",
    "active-space observer closure and wake storage",
)
replace_once(
    router,
    """      Task { @MainActor in self?.reconfigure(force: true) }
    }
  }

  private func registerTerminateObserver() {
    NotificationCenter.default.addObserver(
      forName: NSApplication.willTerminateNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.teardownAll() }
    }
  }
""",
    """      Task { @MainActor in self?.reconfigure(force: true) }
    })
  }
""",
    "wake observer closure and terminate observer removal",
)

replace_once(
    router,
    """  private func handleDisplayRoutingChange() {
    reconfigureWorkItem?.cancel()
""",
    """  private func handleDisplayRoutingChange() {
    guard !hasTornDown else { return }
    reconfigureWorkItem?.cancel()
""",
    "routing teardown guard",
)
replace_once(
    router,
    """  private func scheduleReconfigure(force: Bool = false) {
    reconfigureWorkItem?.cancel()
""",
    """  private func scheduleReconfigure(force: Bool = false) {
    guard !hasTornDown else { return }
    reconfigureWorkItem?.cancel()
""",
    "reprobe scheduling teardown guard",
)

contract_text = contract.read_text()
anchor = """grep -q 'private var hasTornDown' "$APP_DELEGATE" \\
  || fail "Application teardown must be idempotent across Quit and willTerminate callbacks."
"""
addition = anchor + """grep -q 'CGDisplayRemoveReconfigurationCallback' "$ROUTER" \\
  || fail "Router teardown must unregister the unretained Core Graphics callback."
grep -q 'defaultNotificationObservers' "$ROUTER" \\
  || fail "Router teardown must own and remove default notification observers."
grep -q 'workspaceNotificationObservers' "$ROUTER" \\
  || fail "Router teardown must own and remove workspace notification observers."
if grep -q 'registerTerminateObserver' "$ROUTER"; then
  fail "Router teardown must be driven synchronously by the application delegate, not a queued termination observer."
fi
grep -q 'guard !hasTornDown, generation == reconfigurationGeneration' "$ROUTER" \\
  || fail "Late probe results must be invalidated after router teardown."
"""
if contract_text.count(anchor) != 1:
    raise RuntimeError(f"lifetime contract anchor: expected one match, found {contract_text.count(anchor)}")
contract.write_text(contract_text.replace(anchor, addition, 1))

print("Applied terminal DisplayRouter lifetime ownership fixes.")
