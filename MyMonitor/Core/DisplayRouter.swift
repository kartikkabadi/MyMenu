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
  private(set) var isReconfiguring = false

  private var backends: [CGDirectDisplayID: any BrightnessBackend] = [:]
  private var reconfigureWorkItem: DispatchWorkItem?
  private var overlayTransitionEndWorkItem: DispatchWorkItem?
  private var gammaHoldDisplayIDs: Set<CGDirectDisplayID> = []
  private var reconfigurationGeneration: UInt64 = 0
  private var defaultNotificationObservers: [NSObjectProtocol] = []
  private var workspaceNotificationObservers: [NSObjectProtocol] = []
  private var hasTornDown = false
  private let defaults = UserDefaults.standard

  private static let overlayTransitionDuration: TimeInterval = 0.9
  private static let preferencesVersion = "v2"
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

  /// One row per external display in extended mode; one representative for a full mirror.
  var presentationDisplays: [ExternalDisplayItem] {
    let mirroredIDs = Set(
      displays.compactMap { item in
        CGDisplayIsInMirrorSet(item.id) != 0 ? item.id : nil
      }
    )
    let presentationIDs = DisplayReconfigurationPolicy.presentationIDs(
      connected: displays.map(\.id),
      mirrored: mirroredIDs,
      isFullMirror: Self.isMirrorMode
    )
    return presentationIDs.compactMap { displayID in
      displays.first { $0.id == displayID }
    }
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

  /// Update one display. A collapsed full-mirror row fans the same requested value out to every
  /// connected external member; each display still clamps and persists against its own range.
  func setBrightness(
    _ value: Double,
    for displayID: CGDirectDisplayID,
    animated: Bool = false,
    persist: Bool = true
  ) {
    guard !hasTornDown else { return }

    let mirroredIDs = Set(
      displays.compactMap { item in
        CGDisplayIsInMirrorSet(item.id) != 0 ? item.id : nil
      }
    )
    let targetIDs = DisplayReconfigurationPolicy.controlIDs(
      connected: displays.map(\.id),
      mirrored: mirroredIDs,
      selected: displayID,
      isFullMirror: Self.isMirrorMode
    )

    for targetID in targetIDs {
      let allowedRange = displays.first(where: { $0.id == targetID })?.allowedRange ?? 0...1
      let clamped = min(
        max(value, allowedRange.lowerBound),
        allowedRange.upperBound
      )
      backends[targetID]?.setBrightness(clamped, animated: animated)

      if let index = displays.firstIndex(where: { $0.id == targetID }) {
        displays[index].brightness = clamped
        rememberDisplay(targetID, name: displays[index].name)
      }
      if persist {
        persistBrightness(clamped, displayID: targetID)
      }
    }
  }

  /// Persist and apply new per-display bounds. Tightening a bound is an explicit user action,
  /// so an out-of-range connected display is moved to the nearest valid brightness immediately.
  func setBrightnessRange(
    _ range: ClosedRange<Double>,
    for displayID: CGDirectDisplayID
  ) {
    guard !hasTornDown else { return }
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
    guard !hasTornDown else { return }
    persistControlPreference(preference, displayID: displayID)
    rememberDisplay(
      displayID,
      name: displays.first(where: { $0.id == displayID })?.name
        ?? loadDisplayName(displayID: displayID)
        ?? "External Display"
    )

    guard let index = displays.firstIndex(where: { $0.id == displayID }) else { return }
    displays[index].controlPreference = preference
    reconfigure(force: true)
  }

  /// Remove all saved values for one display without changing its current physical brightness.
  func forgetDisplayConfiguration(for displayID: CGDirectDisplayID) {
    guard !hasTornDown else { return }
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

  /// Re-probe only when the connected set changes unless a user explicitly requests a retry or
  /// changes the preferred control method. Existing controls remain alive while slow DDC work
  /// completes, and the final backend set is swapped atomically on the main actor.
  func reconfigure(force: Bool = false) {
    guard !hasTornDown else { return }
    reconfigureWorkItem?.cancel()
    reconfigureWorkItem = nil

    let externalIDs = Set(Self.onlineExternalDisplayIDs())

    guard !externalIDs.isEmpty else {
      invalidatePendingReconfiguration()
      teardownInstalledBackends()
      displays = []
      return
    }

    if !force, externalIDs == Set(backends.keys), !backends.isEmpty {
      refreshDisplayNames()
      syncOverlayLayout()
      return
    }

    reconfigurationGeneration &+= 1
    let generation = reconfigurationGeneration
    isReconfiguring = true

    removeDisconnectedBackends(keeping: externalIDs)

    let inputs = externalIDs.sorted().map { displayID in
      ReconfigurationInput(
        displayID: displayID,
        preference: loadControlPreference(displayID: displayID),
        forceOverlay: Self.shouldUseOverlayForMirror(displayID: displayID)
      )
    }

    let ddcCandidateIDs = inputs.compactMap { input -> CGDirectDisplayID? in
      guard !input.forceOverlay, input.preference != .shade else { return nil }
      return input.displayID
    }

    DDCBrightnessBackend.probe(displayIDs: ddcCandidateIDs) { [weak self] results in
      guard let self else {
        Self.invalidate(results)
        return
      }
      self.applyReconfiguration(
        inputs: inputs,
        ddcResults: results,
        generation: generation
      )
    }
  }

  func teardownAll() {
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

  // MARK: - Reconfiguration

  private struct ReconfigurationInput {
    let displayID: CGDirectDisplayID
    let preference: BrightnessControlPreference
    let forceOverlay: Bool
  }

  private func applyReconfiguration(
    inputs: [ReconfigurationInput],
    ddcResults: [CGDirectDisplayID: DDCProbeResult],
    generation: UInt64
  ) {
    guard !hasTornDown, generation == reconfigurationGeneration else {
      Self.invalidate(ddcResults)
      return
    }

    let expectedIDs = Set(inputs.map(\.displayID))
    guard expectedIDs == Set(Self.onlineExternalDisplayIDs()) else {
      Self.invalidate(ddcResults)
      handleDisplayRoutingChange()
      return
    }

    var nextBackends: [CGDirectDisplayID: any BrightnessBackend] = [:]
    var nextDisplays: [ExternalDisplayItem] = []
    nextBackends.reserveCapacity(inputs.count)
    nextDisplays.reserveCapacity(inputs.count)

    for input in inputs {
      let displayID = input.displayID
      let name = Self.displayName(displayID)
      let preference = loadControlPreference(displayID: displayID)
      let allowedRange = loadBrightnessRange(displayID: displayID)
      let forceOverlay = Self.shouldUseOverlayForMirror(displayID: displayID)
      let ddcResult = ddcResults[displayID]
      let gammaAvailable = gammaCapability(
        for: displayID,
        preference: preference,
        hasDDC: ddcResult != nil,
        forceOverlay: forceOverlay
      )
      let tier = Self.resolveTier(
        preference: preference,
        forceOverlay: forceOverlay,
        hasDDC: ddcResult != nil,
        hasGamma: gammaAvailable
      )

      if tier != .ddc {
        ddcResult?.invalidate()
      }

      let brightness = DisplayReconfigurationPolicy.resolvedBrightness(
        live: displays.first(where: { $0.id == displayID })?.brightness,
        persisted: loadBrightness(displayID: displayID),
        probed: tier == .ddc ? ddcResult?.currentBrightness : nil,
        allowedRange: allowedRange
      )

      let backend = Self.makeBackend(
        displayID: displayID,
        tier: tier,
        brightness: brightness,
        ddcResult: ddcResult
      )
      nextBackends[displayID] = backend
      nextDisplays.append(
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

    teardownInstalledBackends()
    backends = nextBackends
    displays = nextDisplays.sorted {
      $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
    isReconfiguring = false
  }

  private func gammaCapability(
    for displayID: CGDirectDisplayID,
    preference: BrightnessControlPreference,
    hasDDC: Bool,
    forceOverlay: Bool
  ) -> Bool {
    guard !forceOverlay, preference != .shade else { return false }

    switch preference {
    case .automatic, .hardware:
      if hasDDC { return false }
    case .software:
      break
    case .shade:
      return false
    }

    if backends[displayID] is GammaBrightnessBackend {
      return true
    }
    return GammaBrightnessBackend.probe(displayID: displayID)
  }

  private static func resolveTier(
    preference: BrightnessControlPreference,
    forceOverlay: Bool,
    hasDDC: Bool,
    hasGamma: Bool
  ) -> BrightnessTier {
    if forceOverlay { return .overlay }

    switch preference {
    case .automatic, .hardware:
      if hasDDC { return .ddc }
      if hasGamma { return .gamma }
      return .overlay

    case .software:
      if hasGamma { return .gamma }
      if hasDDC { return .ddc }
      return .overlay

    case .shade:
      return .overlay
    }
  }

  private static func makeBackend(
    displayID: CGDirectDisplayID,
    tier: BrightnessTier,
    brightness: Double,
    ddcResult: DDCProbeResult?
  ) -> any BrightnessBackend {
    let backend: any BrightnessBackend
    switch tier {
    case .ddc:
      if let ddcResult {
        backend = DDCBrightnessBackend(probeResult: ddcResult)
      } else {
        backend = DDCBrightnessBackend(displayID: displayID)
      }
    case .gamma:
      backend = GammaBrightnessBackend(displayID: displayID)
    case .overlay:
      backend = OverlayBrightnessBackend(displayID: displayID)
    }
    backend.setBrightness(brightness, animated: false)
    return backend
  }

  private func removeDisconnectedBackends(
    keeping externalIDs: Set<CGDirectDisplayID>
  ) {
    let removedIDs = DisplayReconfigurationPolicy.removedIDs(
      installed: Set(backends.keys),
      online: externalIDs
    )

    for displayID in removedIDs {
      if gammaHoldDisplayIDs.remove(displayID) != nil {
        DisplayGamma.releaseHold(displayID: displayID, includeBuiltin: true)
      }
      backends.removeValue(forKey: displayID)?.teardown()
    }
    displays.removeAll { !externalIDs.contains($0.id) }
  }

  private func invalidatePendingReconfiguration() {
    reconfigureWorkItem?.cancel()
    reconfigureWorkItem = nil
    reconfigurationGeneration &+= 1
    isReconfiguring = false
  }

  private static func invalidate(
    _ results: [CGDirectDisplayID: DDCProbeResult]
  ) {
    for result in results.values {
      result.invalidate()
    }
  }

  private func teardownInstalledBackends() {
    overlayTransitionEndWorkItem?.cancel()
    overlayTransitionEndWorkItem = nil

    DisplayGamma.releaseHolds(gammaHoldDisplayIDs, includeBuiltin: true)
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
    guard !hasTornDown else { return }
    overlayTransitionEndWorkItem?.cancel()
    beginOverlaySpaceTransition()

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
    DisplayGamma.releaseHolds(gammaHoldDisplayIDs, includeBuiltin: true)
    gammaHoldDisplayIDs.removeAll()

    for overlay in overlayBackends {
      overlay.finalizeAfterSpaceTransition()
    }
  }

  private static var isMirrorMode: Bool {
    guard NSScreen.screens.count == 1 else { return false }
    return allOnlineDisplayIDs().contains { CGDisplayIsInMirrorSet($0) != 0 }
  }

  private static func mirroredOnlineDisplayIDs(for displayID: CGDirectDisplayID) -> [CGDirectDisplayID] {
    guard CGDisplayIsInMirrorSet(displayID) != 0 else { return [displayID] }
    let mirrored = allOnlineDisplayIDs().filter { CGDisplayIsInMirrorSet($0) != 0 }
    return mirrored.isEmpty ? [displayID] : mirrored
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
    CGDisplayRegisterReconfigurationCallback(
      Self.displayReconfigurationCallback,
      Unmanaged.passUnretained(self).toOpaque()
    )
  }

  private func registerScreenObservers() {
    defaultNotificationObservers.append(NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      // This notification is the fallback for mode/mirror transitions whose Core Graphics flag
      // sequence varies by macOS release or adapter. Debouncing happens inside the routing path.
      Task { @MainActor in self?.handleDisplayRoutingChange() }
    })

    workspaceNotificationObservers.append(NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.scheduleOverlaySpaceSync() }
    })
  }

  private func registerWakeObserver() {
    workspaceNotificationObservers.append(NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      // Wake invalidates any pre-sleep probe immediately; delaying generation advancement allows a
      // stale service result to install during the debounce window.
      Task { @MainActor in self?.reconfigure(force: true) }
    })
  }

  /// Reconcile hot-plug, display-mode, and mirror-routing changes. Stale rows and resources are
  /// removed immediately; only the expensive capability reprobe is debounced.
  private func handleDisplayRoutingChange() {
    guard !hasTornDown else { return }
    reconfigureWorkItem?.cancel()
    reconfigureWorkItem = nil
    reconfigurationGeneration &+= 1

    // A topology change can arrive during mirror/Space stabilization. End that transition before
    // removing backends so built-in or peer-display gamma holds cannot outlive the old topology.
    overlayTransitionEndWorkItem?.cancel()
    overlayTransitionEndWorkItem = nil
    endOverlaySpaceTransition()

    let externalIDs = Set(Self.onlineExternalDisplayIDs())
    removeDisconnectedBackends(keeping: externalIDs)

    guard !externalIDs.isEmpty else {
      isReconfiguring = false
      teardownInstalledBackends()
      displays = []
      return
    }

    isReconfiguring = true
    scheduleReconfigure(force: true)
  }

  private func scheduleReconfigure(force: Bool = false) {
    guard !hasTornDown else { return }
    reconfigureWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
      Task { @MainActor in self?.reconfigure(force: force) }
    }
    reconfigureWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
  }
}
