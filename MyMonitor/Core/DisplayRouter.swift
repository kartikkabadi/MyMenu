import AppKit
import CoreGraphics
import Foundation
import Observation

struct ExternalDisplayItem: Identifiable, Equatable {
  let id: CGDirectDisplayID
  var name: String
  var brightness: Double
  var tier: BrightnessTier
  var allowedRange: ClosedRange<Double>
  var controlPreference: BrightnessControlPreference

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
  private static let knownDisplayIDsKey = "MyMonitor.v2.knownDisplayIDs"

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

  /// Connected displays first, followed by remembered disconnected displays.
  var configurationDisplays: [DisplayConfigurationItem] {
    let connected = displays.map { item in
      DisplayConfigurationItem(
        id: item.id,
        name: item.name,
        isConnected: true,
        brightness: item.brightness,
        allowedRange: item.allowedRange,
        preference: item.controlPreference,
        activeTier: item.tier
      )
    }

    let connectedIDs = Set(displays.map(\.id))
    let disconnected = knownDisplayIDs()
      .filter { !connectedIDs.contains($0) }
      .map { displayID in
        DisplayConfigurationItem(
          id: displayID,
          name: loadDisplayName(displayID: displayID) ?? "External Display",
          isConnected: false,
          brightness: loadBrightness(displayID: displayID),
          allowedRange: loadBrightnessRange(displayID: displayID),
          preference: loadControlPreference(displayID: displayID),
          activeTier: nil
        )
      }

    return connected.sorted(by: Self.configurationSort)
      + disconnected.sorted(by: Self.configurationSort)
  }

  /// Update one display. Drag updates stay in memory; the final value is persisted on release.
  func setBrightness(
    _ value: Double,
    for displayID: CGDirectDisplayID,
    animated: Bool = false,
    persist: Bool = true
  ) {
    let allowedRange = displays.first(where: { $0.id == displayID })?.allowedRange ?? 0...1
    let clamped = min(
      max(value, allowedRange.lowerBound),
      allowedRange.upperBound
    )
    backends[displayID]?.setBrightness(clamped, animated: animated)

    if let index = displays.firstIndex(where: { $0.id == displayID }) {
      displays[index].brightness = clamped
      rememberDisplay(displayID, name: displays[index].name)
    }
    if persist {
      persistBrightness(clamped, displayID: displayID)
    }
  }

  /// Persist and apply new per-display bounds. Tightening a bound is an explicit user action,
  /// so an out-of-range connected display is moved to the nearest valid brightness immediately.
  func setBrightnessRange(
    _ range: ClosedRange<Double>,
    for displayID: CGDirectDisplayID
  ) {
    let lower = min(max(range.lowerBound, 0), 1)
    let upper = min(max(range.upperBound, 0), 1)
    let normalized = min(lower, upper)...max(lower, upper)

    persistBrightnessRange(normalized, displayID: displayID)
    rememberDisplay(
      displayID,
      name: displays.first(where: { $0.id == displayID })?.name
        ?? loadDisplayName(displayID: displayID)
        ?? "External Display"
    )

    guard let index = displays.firstIndex(where: { $0.id == displayID }) else { return }
    displays[index].allowedRange = normalized

    let current = displays[index].brightness
    let clamped = min(max(current, normalized.lowerBound), normalized.upperBound)
    if abs(current - clamped) > 0.0001 {
      setBrightness(clamped, for: displayID, animated: false, persist: true)
    }
  }

  /// Persist a requested control strategy. Unsupported forced modes fall back through the
  /// automatic cascade while the configuration snapshot reports both requested and active modes.
  func setControlPreference(
    _ preference: BrightnessControlPreference,
    for displayID: CGDirectDisplayID
  ) {
    persistControlPreference(preference, displayID: displayID)
    rememberDisplay(
      displayID,
      name: displays.first(where: { $0.id == displayID })?.name
        ?? loadDisplayName(displayID: displayID)
        ?? "External Display"
    )

    guard displays.contains(where: { $0.id == displayID }) else { return }
    reconfigure(force: true)
  }

  /// Remove all saved values for one display without changing its current physical brightness.
  func forgetDisplayConfiguration(for displayID: CGDirectDisplayID) {
    for suffix in [
      "brightness",
      "minimumBrightness",
      "maximumBrightness",
      "controlPreference",
      "name",
      "tier",
    ] {
      defaults.removeObject(forKey: prefsKey(suffix, displayID: displayID))
    }
    forgetKnownDisplayID(displayID)

    guard let index = displays.firstIndex(where: { $0.id == displayID }) else { return }
    displays[index].allowedRange = 0...1
    displays[index].controlPreference = .automatic
  }

  /// Re-probe only when the set of connected external displays changes unless a user explicitly
  /// changes the preferred control method.
  func reconfigure(force: Bool = false) {
    let externalIDs = Set(Self.onlineExternalDisplayIDs())

    guard !externalIDs.isEmpty else {
      teardownAll()
      displays = []
      return
    }

    if !force, externalIDs == Set(backends.keys), !backends.isEmpty {
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
      let preference = loadControlPreference(displayID: displayID)
      let tier = Self.resolveTier(for: displayID, preference: preference)
      let allowedRange = loadBrightnessRange(displayID: displayID)
      let brightness = min(
        max(
          loadBrightness(displayID: displayID)
            ?? Self.currentBrightness(displayID: displayID, tier: tier)
            ?? 1,
          allowedRange.lowerBound
        ),
        allowedRange.upperBound
      )
      let backend = Self.makeBackend(
        displayID: displayID,
        tier: tier,
        brightness: brightness
      )
      let name = Self.displayName(displayID)

      backends[displayID] = backend
      items.append(
        ExternalDisplayItem(
          id: displayID,
          name: name,
          brightness: brightness,
          tier: tier,
          allowedRange: allowedRange,
          controlPreference: preference
        )
      )
      rememberDisplay(displayID, name: name)
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

  private static func resolveTier(
    for displayID: CGDirectDisplayID,
    preference: BrightnessControlPreference
  ) -> BrightnessTier {
    if shouldUseOverlayForMirror(displayID: displayID) {
      return .overlay
    }

    switch preference {
    case .automatic:
      return resolveAutomaticTier(for: displayID)

    case .hardware:
      if DDCBrightnessBackend.probe(displayID: displayID) {
        return .ddc
      }
      return resolveAutomaticTier(for: displayID, skipDDC: true)

    case .software:
      if GammaBrightnessBackend.probe(displayID: displayID) {
        return .gamma
      }
      return resolveAutomaticTier(for: displayID, skipGamma: true)

    case .shade:
      return .overlay
    }
  }

  private static func resolveAutomaticTier(
    for displayID: CGDirectDisplayID,
    skipDDC: Bool = false,
    skipGamma: Bool = false
  ) -> BrightnessTier {
    if !skipDDC, DDCBrightnessBackend.probe(displayID: displayID) {
      return .ddc
    }
    if !skipGamma, GammaBrightnessBackend.probe(displayID: displayID) {
      return .gamma
    }
    return .overlay
  }

  private static func currentBrightness(
    displayID: CGDirectDisplayID,
    tier: BrightnessTier
  ) -> Double? {
    guard tier == .ddc else { return nil }
    return DDCBrightnessBackend.currentBrightness(displayID: displayID)
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

  private static func configurationSort(
    _ lhs: DisplayConfigurationItem,
    _ rhs: DisplayConfigurationItem
  ) -> Bool {
    lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
  }

  private func refreshDisplayNames() {
    displays = displays.map { item in
      var updated = item
      updated.name = Self.displayName(item.id)
      rememberDisplay(updated.id, name: updated.name)
      return updated
    }
  }

  // MARK: - Persistence

  private func prefsKey(_ suffix: String, displayID: CGDirectDisplayID) -> String {
    "MyMonitor.\(Self.preferencesVersion).\(displayID).\(suffix)"
  }

  private func loadBrightness(displayID: CGDirectDisplayID) -> Double? {
    let key = prefsKey("brightness", displayID: displayID)
    guard defaults.object(forKey: key) != nil else { return nil }
    return min(max(defaults.double(forKey: key), 0), 1)
  }

  private func persistBrightness(_ value: Double, displayID: CGDirectDisplayID) {
    defaults.set(value, forKey: prefsKey("brightness", displayID: displayID))
  }

  private func loadBrightnessRange(
    displayID: CGDirectDisplayID
  ) -> ClosedRange<Double> {
    let minimumKey = prefsKey("minimumBrightness", displayID: displayID)
    let maximumKey = prefsKey("maximumBrightness", displayID: displayID)
    let minimum = defaults.object(forKey: minimumKey) == nil
      ? 0
      : min(max(defaults.double(forKey: minimumKey), 0), 1)
    let maximum = defaults.object(forKey: maximumKey) == nil
      ? 1
      : min(max(defaults.double(forKey: maximumKey), 0), 1)
    return min(minimum, maximum)...max(minimum, maximum)
  }

  private func persistBrightnessRange(
    _ range: ClosedRange<Double>,
    displayID: CGDirectDisplayID
  ) {
    defaults.set(
      range.lowerBound,
      forKey: prefsKey("minimumBrightness", displayID: displayID)
    )
    defaults.set(
      range.upperBound,
      forKey: prefsKey("maximumBrightness", displayID: displayID)
    )
  }

  private func loadControlPreference(
    displayID: CGDirectDisplayID
  ) -> BrightnessControlPreference {
    let rawValue = defaults.string(
      forKey: prefsKey("controlPreference", displayID: displayID)
    )
    return rawValue.flatMap(BrightnessControlPreference.init(rawValue:)) ?? .automatic
  }

  private func persistControlPreference(
    _ preference: BrightnessControlPreference,
    displayID: CGDirectDisplayID
  ) {
    defaults.set(
      preference.rawValue,
      forKey: prefsKey("controlPreference", displayID: displayID)
    )
  }

  private func loadDisplayName(displayID: CGDirectDisplayID) -> String? {
    defaults.string(forKey: prefsKey("name", displayID: displayID))
  }

  private func persistTier(_ tier: BrightnessTier, displayID: CGDirectDisplayID) {
    defaults.set(tier.rawValue, forKey: prefsKey("tier", displayID: displayID))
  }

  private func knownDisplayIDs() -> Set<CGDirectDisplayID> {
    let values = defaults.stringArray(forKey: Self.knownDisplayIDsKey) ?? []
    return Set(values.compactMap(CGDirectDisplayID.init))
  }

  private func rememberDisplay(_ displayID: CGDirectDisplayID, name: String) {
    var values = knownDisplayIDs()
    values.insert(displayID)
    defaults.set(
      values.map(String.init).sorted(),
      forKey: Self.knownDisplayIDsKey
    )
    defaults.set(name, forKey: prefsKey("name", displayID: displayID))
  }

  private func forgetKnownDisplayID(_ displayID: CGDirectDisplayID) {
    var values = knownDisplayIDs()
    values.remove(displayID)
    defaults.set(
      values.map(String.init).sorted(),
      forKey: Self.knownDisplayIDsKey
    )
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
