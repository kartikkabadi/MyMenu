import AppKit
import CoreGraphics
import Foundation
import Observation

struct ExternalDisplayItem: Identifiable, Equatable {
  let id: CGDirectDisplayID
  var name: String
  var brightness: Double
  var tier: BrightnessTier

  var tierLabel: String {
    switch tier {
    case .ddc: "Hardware control"
    case .gamma: "Software control"
    case .overlay: "Display shade"
    }
  }
}

/// Owns external-display discovery, backend selection, persistence, and lifecycle.
/// The UI only deals in one invariant: 0 is darkest and 1 is brightest.
@MainActor
@Observable
final class DisplayRouter {
  private(set) var displays: [ExternalDisplayItem] = []

  private var backends: [CGDirectDisplayID: any BrightnessBackend] = [:]
  private var reconfigureWorkItem: DispatchWorkItem?
  private var overlayTransitionEndWorkItem: DispatchWorkItem?
  private var gammaHoldDisplayIDs: Set<CGDirectDisplayID> = []
  private let defaults = UserDefaults.standard

  private static let overlayTransitionDuration: TimeInterval = 0.9
  private static let preferencesVersion = "v2"

  init() {
    reconfigure()
    registerDisplayCallbacks()
    registerScreenObservers()
    registerWakeObserver()
    registerTerminateObserver()
  }

  /// One row per external display in extended mode; one row for a mirrored set.
  var presentationDisplays: [ExternalDisplayItem] {
    guard displays.count > 1 else { return displays }

    let mirrored = displays.filter { CGDisplayIsInMirrorSet($0.id) != 0 }
    if mirrored.count == 1 {
      return [mirrored[0]]
    }
    return displays
  }

  /// Update one display. Drag updates stay in memory; the final value is persisted on release.
  func setBrightness(
    _ value: Double,
    for displayID: CGDirectDisplayID,
    animated: Bool = false,
    persist: Bool = true
  ) {
    let clamped = min(max(value, 0), 1)
    backends[displayID]?.setBrightness(clamped, animated: animated)

    if let index = displays.firstIndex(where: { $0.id == displayID }) {
      displays[index].brightness = clamped
    }
    if persist {
      persistBrightness(clamped, displayID: displayID)
    }
  }

  /// Re-probe only when the set of connected external displays changes.
  /// Layout and Space changes must not destroy working DDC connections or reset slider state.
  func reconfigure() {
    let externalIDs = Set(Self.onlineExternalDisplayIDs())

    guard !externalIDs.isEmpty else {
      teardownAll()
      displays = []
      return
    }

    if externalIDs == Set(backends.keys), !backends.isEmpty {
      refreshDisplayNames()
      syncOverlayLayout()
      return
    }

    teardownAll()

    if Arm64DDC.isArm64 {
      _ = Arm64DDC.getServiceMatches(displayIDs: externalIDs.sorted())
    }

    var items: [ExternalDisplayItem] = []
    for displayID in externalIDs.sorted() {
      let tier = Self.resolveTier(for: displayID)
      let savedBrightness = loadBrightness(displayID: displayID)
      let backend = Self.makeBackend(
        displayID: displayID,
        tier: tier,
        brightness: savedBrightness
      )

      backends[displayID] = backend
      items.append(
        ExternalDisplayItem(
          id: displayID,
          name: Self.displayName(displayID),
          brightness: savedBrightness,
          tier: tier
        )
      )
      persistTier(tier, displayID: displayID)
    }

    displays = items.sorted {
      $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
  }

  func teardownAll() {
    overlayTransitionEndWorkItem?.cancel()
    overlayTransitionEndWorkItem = nil

    for displayID in gammaHoldDisplayIDs {
      DisplayGamma.releaseHold(displayID: displayID, includeBuiltin: true)
    }
    gammaHoldDisplayIDs.removeAll()

    for backend in backends.values {
      backend.teardown()
    }
    backends.removeAll()
  }

  // MARK: - Overlay lifecycle

  private var overlayBackends: [OverlayBrightnessBackend] {
    backends.values.compactMap { $0 as? OverlayBrightnessBackend }
  }

  private func syncOverlayLayout() {
    for overlay in overlayBackends {
      overlay.finalizeAfterSpaceTransition()
    }
  }

  private func scheduleOverlaySpaceSync() {
    beginOverlaySpaceTransition()
    overlayTransitionEndWorkItem?.cancel()

    let endWork = DispatchWorkItem { [weak self] in
      self?.endOverlaySpaceTransition()
    }
    overlayTransitionEndWorkItem = endWork
    DispatchQueue.main.asyncAfter(
      deadline: .now() + Self.overlayTransitionDuration,
      execute: endWork
    )
  }

  private func beginOverlaySpaceTransition() {
    for item in displays where item.brightness < 0.999 {
      guard let overlay = backends[item.id] as? OverlayBrightnessBackend else { continue }

      if Self.isMirrorMode {
        for displayID in Self.mirroredOnlineDisplayIDs(for: item.id) {
          DisplayGamma.applyBrightnessHold(
            item.brightness,
            displayID: displayID,
            includeBuiltin: true
          )
          gammaHoldDisplayIDs.insert(displayID)
        }
      }

      overlay.setSuppressOrderFront(true)
      overlay.reaffirmAlphaDuringTransition()
    }
  }

  private func endOverlaySpaceTransition() {
    for displayID in gammaHoldDisplayIDs {
      DisplayGamma.releaseHold(displayID: displayID, includeBuiltin: true)
    }
    gammaHoldDisplayIDs.removeAll()

    for overlay in overlayBackends {
      overlay.finalizeAfterSpaceTransition()
    }
  }

  private static var isMirrorMode: Bool {
    NSScreen.screens.count == 1
  }

  private static func mirroredOnlineDisplayIDs(for displayID: CGDirectDisplayID) -> [CGDirectDisplayID] {
    let online = allOnlineDisplayIDs()
    if isMirrorMode {
      return online.isEmpty ? [displayID] : online
    }

    guard CGDisplayIsInMirrorSet(displayID) != 0 else { return [displayID] }
    let mirrored = online.filter { CGDisplayIsInMirrorSet($0) != 0 }
    return mirrored.isEmpty ? [displayID] : mirrored
  }

  // MARK: - Tier cascade

  private static func resolveTier(for displayID: CGDirectDisplayID) -> BrightnessTier {
    if shouldUseOverlayForMirror(displayID: displayID) {
      return .overlay
    }
    if DDCBrightnessBackend.probe(displayID: displayID) {
      return .ddc
    }
    if GammaBrightnessBackend.probe(displayID: displayID) {
      return .gamma
    }
    return .overlay
  }

  private static func makeBackend(
    displayID: CGDirectDisplayID,
    tier: BrightnessTier,
    brightness: Double
  ) -> any BrightnessBackend {
    let backend: any BrightnessBackend
    switch tier {
    case .ddc:
      backend = DDCBrightnessBackend(displayID: displayID)
    case .gamma:
      backend = GammaBrightnessBackend(displayID: displayID)
    case .overlay:
      backend = OverlayBrightnessBackend(displayID: displayID)
    }
    backend.setBrightness(brightness, animated: false)
    return backend
  }

  private static func shouldUseOverlayForMirror(displayID: CGDirectDisplayID) -> Bool {
    guard CGDisplayIsBuiltin(displayID) == 0 else { return false }
    guard CGDisplayIsInMirrorSet(displayID) != 0 else { return false }
    return NSScreen.screens.count == 1
  }

  // MARK: - Display enumeration

  private static func onlineExternalDisplayIDs() -> [CGDirectDisplayID] {
    allOnlineDisplayIDs().filter { CGDisplayIsBuiltin($0) == 0 }
  }

  private static func allOnlineDisplayIDs() -> [CGDirectDisplayID] {
    var ids = [CGDirectDisplayID](repeating: 0, count: 32)
    var count: UInt32 = 0
    guard CGGetOnlineDisplayList(32, &ids, &count) == .success else { return [] }
    return Array(ids.prefix(Int(count)))
  }

  private static func displayName(_ displayID: CGDirectDisplayID) -> String {
    let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
    if let screen = NSScreen.screens.first(where: { screen in
      guard let number = screen.deviceDescription[screenNumberKey] as? NSNumber else {
        return false
      }
      return CGDirectDisplayID(number.uint32Value) == displayID
    }) {
      return screen.localizedName
    }
    return "External Display"
  }

  private func refreshDisplayNames() {
    displays = displays.map { item in
      var updated = item
      updated.name = Self.displayName(item.id)
      return updated
    }
  }

  // MARK: - Persistence

  private func prefsKey(_ suffix: String, displayID: CGDirectDisplayID) -> String {
    "MyMonitor.\(Self.preferencesVersion).\(displayID).\(suffix)"
  }

  private func loadBrightness(displayID: CGDirectDisplayID) -> Double {
    let key = prefsKey("brightness", displayID: displayID)
    guard defaults.object(forKey: key) != nil else { return 1 }
    return min(max(defaults.double(forKey: key), 0), 1)
  }

  private func persistBrightness(_ value: Double, displayID: CGDirectDisplayID) {
    defaults.set(value, forKey: prefsKey("brightness", displayID: displayID))
  }

  private func persistTier(_ tier: BrightnessTier, displayID: CGDirectDisplayID) {
    defaults.set(tier.rawValue, forKey: prefsKey("tier", displayID: displayID))
  }

  // MARK: - Hot-plug, Spaces, and wake

  private func registerDisplayCallbacks() {
    let callback: CGDisplayReconfigurationCallBack = { _, flags, userInfo in
      guard let userInfo else { return }
      let router = Unmanaged<DisplayRouter>.fromOpaque(userInfo).takeUnretainedValue()

      if flags.contains(.beginConfigurationFlag) {
        Task { @MainActor in router.scheduleOverlaySpaceSync() }
        return
      }

      let layoutOnly: CGDisplayChangeSummaryFlags = [
        .desktopShapeChangedFlag,
        .movedFlag,
        .setMainFlag,
        .setModeFlag,
      ]
      if flags.isSubset(of: layoutOnly) {
        Task { @MainActor in router.scheduleOverlaySpaceSync() }
        return
      }

      guard flags.contains(.addFlag) || flags.contains(.removeFlag) else { return }
      Task { @MainActor in router.scheduleReconfigure() }
    }

    let unmanaged = Unmanaged.passUnretained(self)
    CGDisplayRegisterReconfigurationCallback(callback, unmanaged.toOpaque())
  }

  private func registerScreenObservers() {
    NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.scheduleOverlaySpaceSync() }
    }

    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.scheduleOverlaySpaceSync() }
    }
  }

  private func registerWakeObserver() {
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.scheduleReconfigure() }
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

  private func scheduleReconfigure() {
    reconfigureWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
      Task { @MainActor in self?.reconfigure() }
    }
    reconfigureWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
  }
}
