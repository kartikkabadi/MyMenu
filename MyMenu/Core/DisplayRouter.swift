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
    case .ddc: "Hardware brightness"
    case .gamma: "Software gamma"
    case .overlay: "Screen overlay"
    }
  }
}

@MainActor
@Observable
final class DisplayRouter {
  private(set) var displays: [ExternalDisplayItem] = []
  private var backends: [CGDirectDisplayID: any BrightnessBackend] = [:]
  private var reconfigureWorkItem: DispatchWorkItem?
  private var overlayTransitionEndWorkItem: DispatchWorkItem?
  private var overlayInSpaceTransition = false
  private var gammaHoldDisplayIDs: Set<CGDirectDisplayID> = []
  private let defaults = UserDefaults.standard

  private static let overlayTransitionDuration: TimeInterval = 0.9

  init() {
    reconfigure()
    registerDisplayCallbacks()
    registerScreenObservers()
    registerWakeObserver()
    registerTerminateObserver()
  }

  /// Sliders to show: one per external in extended mode; single external when mirrored.
  var presentationDisplays: [ExternalDisplayItem] {
    let externals = displays
    guard !externals.isEmpty else { return [] }
    if externals.count == 1 { return externals }
    let mirroredExternals = externals.filter { CGDisplayIsInMirrorSet($0.id) != 0 }
    if mirroredExternals.count == 1 {
      return [mirroredExternals[0]]
    }
    return externals
  }

  /// Update brightness. During slider drag use `animated: false` and `persist: false` for responsiveness.
  func setBrightness(
    _ value: Double,
    for displayID: CGDirectDisplayID,
    animated: Bool = false,
    persist: Bool = true
  ) {
    let clamped = min(max(value, 0), 1)
    backends[displayID]?.setBrightness(clamped, animated: animated)
    if persist {
      persistBrightness(clamped, displayID: displayID)
    }
    if let index = displays.firstIndex(where: { $0.id == displayID }) {
      displays[index].brightness = clamped
    }
  }

  func reconfigure() {
    let externalIDs = Set(Self.onlineExternalDisplayIDs())
    guard !externalIDs.isEmpty else {
      teardownAll()
      displays = []
      return
    }

    // Space swipe / layout churn: keep overlay windows, avoid flash.
    if externalIDs == Set(backends.keys), !backends.isEmpty {
      syncOverlayLayout()
      refreshDisplayMetadata()
      return
    }

    teardownAll()

    if Arm64DDC.isArm64 {
      _ = Arm64DDC.getServiceMatches(displayIDs: externalIDs.sorted())
    }

    var items: [ExternalDisplayItem] = []
    for displayID in externalIDs.sorted() {
      let tier = Self.resolveTier(for: displayID)
      let saved = loadBrightness(displayID: displayID)
      let backend = Self.makeBackend(displayID: displayID, tier: tier, saved: saved)
      backends[displayID] = backend
      items.append(
        ExternalDisplayItem(
          id: displayID,
          name: Self.displayName(displayID),
          brightness: saved,
          tier: tier
        )
      )
      persistTier(tier, displayID: displayID)
    }
    displays = items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  /// Relayout overlay frames after Spaces change without destroying windows.
  func syncOverlayLayout() {
    for backend in backends.values {
      if let overlay = backend as? OverlayBrightnessBackend {
        overlay.finalizeAfterSpaceTransition()
      }
    }
  }

  /// Debounced end-of-transition sync (no immediate + delayed double storm).
  private func scheduleOverlaySpaceSync() {
    beginOverlaySpaceTransition()

    overlayTransitionEndWorkItem?.cancel()

    let endWork = DispatchWorkItem { [weak self] in
      self?.endOverlaySpaceTransition()
    }
    overlayTransitionEndWorkItem = endWork
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.overlayTransitionDuration, execute: endWork)
  }

  private func beginOverlaySpaceTransition() {
    overlayInSpaceTransition = true

    for item in displays where item.tier == .overlay && item.brightness > 0.001 {
      if Self.isMirrorMode {
        for displayID in Self.mirroredOnlineDisplayIDs(for: item.id) {
          DisplayGamma.applyBrightnessHold(item.brightness, displayID: displayID, includeBuiltin: true)
          gammaHoldDisplayIDs.insert(displayID)
        }
      }
      if let overlay = backends[item.id] as? OverlayBrightnessBackend {
        overlay.setSuppressOrderFront(true)
        overlay.reaffirmAlphaDuringTransition()
      }
    }
  }

  private func endOverlaySpaceTransition() {
    overlayInSpaceTransition = false

    for displayID in gammaHoldDisplayIDs {
      DisplayGamma.releaseHold(displayID: displayID, includeBuiltin: true)
    }
    gammaHoldDisplayIDs.removeAll()

    for backend in backends.values {
      if let overlay = backend as? OverlayBrightnessBackend {
        overlay.finalizeAfterSpaceTransition()
      }
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

    guard CGDisplayIsInMirrorSet(displayID) != 0 else {
      return [displayID]
    }

    let mirrored = online.filter { CGDisplayIsInMirrorSet($0) != 0 }
    return mirrored.isEmpty ? [displayID] : mirrored
  }

  private func refreshDisplayMetadata() {
    displays = displays.map { item in
      var copy = item
      copy.name = Self.displayName(item.id)
      copy.brightness = loadBrightness(displayID: item.id)
      return copy
    }
  }

  func teardownAll() {
    for backend in backends.values {
      backend.teardown()
    }
    backends.removeAll()
  }

  func quit() {
    AppDelegate.shared.quitApp()
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
    saved: Double
  ) -> any BrightnessBackend {
    switch tier {
    case .overlay:
      let backend = OverlayBrightnessBackend(displayID: displayID)
      backend.setBrightness(saved, animated: false)
      return backend
    case .ddc:
      let backend = DDCBrightnessBackend(displayID: displayID)
      backend.setBrightness(saved, animated: false)
      return backend
    case .gamma:
      let backend = GammaBrightnessBackend(displayID: displayID)
      backend.setBrightness(saved, animated: false)
      return backend
    }
  }

  /// Mirrored desktop collapsed to one screen — prefer shade overlay (HDMI dongle path).
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
    if let screen = NSScreen.screens.first(where: {
      guard let number = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
        return false
      }
      return CGDirectDisplayID(number.uint32Value) == displayID
    }) {
      return screen.localizedName
    }
    return "External Display"
  }

  // MARK: - Persistence

  private func prefsKey(_ suffix: String, displayID: CGDirectDisplayID) -> String {
    "MyMenu.\(displayID).\(suffix)"
  }

  private func loadBrightness(displayID: CGDirectDisplayID) -> Double {
    let key = prefsKey("brightness", displayID: displayID)
    if defaults.object(forKey: key) != nil {
      return min(max(defaults.double(forKey: key), 0), 1)
    }
    return 0
  }

  private func persistBrightness(_ value: Double, displayID: CGDirectDisplayID) {
    defaults.set(value, forKey: prefsKey("brightness", displayID: displayID))
  }

  private func persistTier(_ tier: BrightnessTier, displayID: CGDirectDisplayID) {
    defaults.set(tier.rawValue, forKey: prefsKey("tier", displayID: displayID))
  }

  // MARK: - Hot-plug & wake

  private func registerDisplayCallbacks() {
    let callback: CGDisplayReconfigurationCallBack = { _, flags, userInfo in
      guard let userInfo else { return }
      let router = Unmanaged<DisplayRouter>.fromOpaque(userInfo).takeUnretainedValue()

      if flags.contains(.beginConfigurationFlag) {
        Task { @MainActor in
          router.scheduleOverlaySpaceSync()
        }
        return
      }

      let layoutOnly: CGDisplayChangeSummaryFlags = [
        .desktopShapeChangedFlag,
        .movedFlag,
        .setMainFlag,
        .setModeFlag,
      ]
      if flags.isSubset(of: layoutOnly) {
        Task { @MainActor in
          router.scheduleOverlaySpaceSync()
        }
        return
      }

      guard flags.contains(.addFlag) || flags.contains(.removeFlag) else {
        return
      }

      Task { @MainActor in
        router.scheduleReconfigure()
      }
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
      Task { @MainActor in
        self?.scheduleOverlaySpaceSync()
      }
    }

    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.scheduleOverlaySpaceSync()
      }
    }

    NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeOcclusionStateNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard NSApp.occlusionState.contains(.visible) else { return }
      Task { @MainActor in
        self?.scheduleOverlaySpaceSync()
      }
    }
  }

  private func registerTerminateObserver() {
    NotificationCenter.default.addObserver(
      forName: NSApplication.willTerminateNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.teardownAll()
      }
    }
  }

  private func registerWakeObserver() {
    NotificationCenter.default.addObserver(
      forName: NSWorkspace.didWakeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.scheduleReconfigure()
      }
    }
  }

  private func scheduleReconfigure() {
    reconfigureWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
      Task { @MainActor in
        self?.reconfigure()
      }
    }
    reconfigureWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
  }
}
