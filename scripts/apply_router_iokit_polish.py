#!/usr/bin/env python3
from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one match in {path}, found {count}")
    path.write_text(text.replace(old, new, 1))
    print(f"Applied: {label}")


router = Path("MyMonitor/Core/DisplayRouter.swift")
arm64 = Path("MyMonitor/ThirdParty/Arm64DDC.swift")

replace_once(
    router,
    '''  /// One row per external display in extended mode; one row for a mirrored set.
  var presentationDisplays: [ExternalDisplayItem] {
    guard displays.count > 1 else { return displays }

    let mirrored = displays.filter { CGDisplayIsInMirrorSet($0.id) != 0 }
    if mirrored.count == 1 {
      return [mirrored[0]]
    }
    return displays
  }
''',
    '''  /// One row per external display in extended mode; one representative for a full mirror.
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
''',
    "mirror presentation",
)

replace_once(
    router,
    '''  private func teardownInstalledBackends() {
    overlayTransitionEndWorkItem?.cancel()
    overlayTransitionEndWorkItem = nil

    for displayID in gammaHoldDisplayIDs {
      DisplayGamma.releaseHold(displayID: displayID, includeBuiltin: true)
    }
    gammaHoldDisplayIDs.removeAll()
''',
    '''  private func teardownInstalledBackends() {
    overlayTransitionEndWorkItem?.cancel()
    overlayTransitionEndWorkItem = nil

    DisplayGamma.releaseHolds(gammaHoldDisplayIDs, includeBuiltin: true)
    gammaHoldDisplayIDs.removeAll()
''',
    "batched teardown hold release",
)

replace_once(
    router,
    '''  private func scheduleOverlaySpaceSync() {
    beginOverlaySpaceTransition()
    overlayTransitionEndWorkItem?.cancel()
''',
    '''  private func scheduleOverlaySpaceSync() {
    overlayTransitionEndWorkItem?.cancel()
    beginOverlaySpaceTransition()
''',
    "overlay timer ordering",
)

replace_once(
    router,
    '''  private func endOverlaySpaceTransition() {
    for displayID in gammaHoldDisplayIDs {
      DisplayGamma.releaseHold(displayID: displayID, includeBuiltin: true)
    }
    gammaHoldDisplayIDs.removeAll()
''',
    '''  private func endOverlaySpaceTransition() {
    DisplayGamma.releaseHolds(gammaHoldDisplayIDs, includeBuiltin: true)
    gammaHoldDisplayIDs.removeAll()
''',
    "batched transition hold release",
)

replace_once(
    router,
    '''  private static var isMirrorMode: Bool {
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
''',
    '''  private static var isMirrorMode: Bool {
    guard NSScreen.screens.count == 1 else { return false }
    return allOnlineDisplayIDs().contains { CGDisplayIsInMirrorSet($0) != 0 }
  }

  private static func mirroredOnlineDisplayIDs(for displayID: CGDirectDisplayID) -> [CGDirectDisplayID] {
    guard CGDisplayIsInMirrorSet(displayID) != 0 else { return [displayID] }
    let mirrored = allOnlineDisplayIDs().filter { CGDisplayIsInMirrorSet($0) != 0 }
    return mirrored.isEmpty ? [displayID] : mirrored
  }
''',
    "true mirror detection",
)

replace_once(
    router,
    '''    ) { [weak self] _ in
      Task { @MainActor in self?.scheduleReconfigure(force: true) }
    }
''',
    '''    ) { [weak self] _ in
      // Wake invalidates any pre-sleep probe immediately; delaying generation advancement allows a
      // stale service result to install during the debounce window.
      Task { @MainActor in self?.reconfigure(force: true) }
    }
''',
    "immediate wake generation",
)

replace_once(
    router,
    '''  private func handleDisplayTopologyChange() {
    reconfigureWorkItem?.cancel()
    reconfigureWorkItem = nil
    reconfigurationGeneration &+= 1

    let externalIDs = Set(Self.onlineExternalDisplayIDs())
''',
    '''  private func handleDisplayTopologyChange() {
    reconfigureWorkItem?.cancel()
    reconfigureWorkItem = nil
    reconfigurationGeneration &+= 1

    // A topology change can arrive during mirror/Space stabilization. End that transition before
    // removing backends so built-in or peer-display gamma holds cannot outlive the old topology.
    overlayTransitionEndWorkItem?.cancel()
    overlayTransitionEndWorkItem = nil
    endOverlaySpaceTransition()

    let externalIDs = Set(Self.onlineExternalDisplayIDs())
''',
    "topology transition cleanup",
)

replace_once(
    arm64,
    '''  static func ioregIterateToNextObjectOfInterest(interests: [String], iterator: inout io_iterator_t) -> (name: String, entry: io_service_t, preceedingEntry: io_service_t)? {
    var entry: io_service_t = IO_OBJECT_NULL
    var preceedingEntry: io_service_t = IO_OBJECT_NULL
    let name = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_name_t>.size)
    defer {
      name.deallocate()
    }
    while true {
      preceedingEntry = entry
      entry = IOIteratorNext(iterator)
      guard IORegistryEntryGetName(entry, name) == KERN_SUCCESS, entry != MACH_PORT_NULL else {
        break
      }
      let nameString = String(cString: name)
      for interest in interests where entry != IO_OBJECT_NULL && nameString.contains(interest) {
        return (nameString, entry, preceedingEntry)
      }
    }
    return nil
  }
''',
    '''  static func ioregIterateToNextObjectOfInterest(
    interests: [String],
    iterator: inout io_iterator_t
  ) -> (name: String, entry: io_service_t)? {
    let name = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_name_t>.size)
    defer { name.deallocate() }

    while true {
      let entry = IOIteratorNext(iterator)
      guard entry != IO_OBJECT_NULL else { return nil }
      guard IORegistryEntryGetName(entry, name) == KERN_SUCCESS else {
        IOObjectRelease(entry)
        continue
      }

      let nameString = String(cString: name)
      if interests.contains(where: nameString.contains) {
        return (nameString, entry)
      }
      IOObjectRelease(entry)
    }
  }
''',
    "IORegistry iterator ownership",
)

replace_once(
    arm64,
    '''    let cpath = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_string_t>.size)
    IORegistryEntryGetPath(entry, kIOServicePlane, cpath)
''',
    '''    let cpath = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_string_t>.size)
    defer { cpath.deallocate() }
    IORegistryEntryGetPath(entry, kIOServicePlane, cpath)
''',
    "IORegistry path buffer ownership",
)

replace_once(
    arm64,
    '''      if keysFramebuffer.contains(objectOfInterest.name) {
        ioregService = self.getIORegServiceAppleCDC2Properties(entry: objectOfInterest.entry)
        serviceLocation += 1
        ioregService.serviceLocation = serviceLocation
      } else if objectOfInterest.name == keyDCPAVServiceProxy {
        self.setIORegServiceDCPAVServiceProxy(entry: objectOfInterest.entry, ioregService: &ioregService)
        ioregServicesForMatching.append(ioregService)
      }
''',
    '''      if keysFramebuffer.contains(objectOfInterest.name) {
        ioregService = self.getIORegServiceAppleCDC2Properties(entry: objectOfInterest.entry)
        serviceLocation += 1
        ioregService.serviceLocation = serviceLocation
      } else if objectOfInterest.name == keyDCPAVServiceProxy {
        self.setIORegServiceDCPAVServiceProxy(entry: objectOfInterest.entry, ioregService: &ioregService)
        ioregServicesForMatching.append(ioregService)
      }
      IOObjectRelease(objectOfInterest.entry)
''',
    "matched IORegistry object ownership",
)

print("Applied router and IOKit lifecycle fixes.")
