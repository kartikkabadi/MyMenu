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

text = router.read_text()
occurrences = text.count("handleDisplayTopologyChange")
if occurrences < 2:
    raise RuntimeError(f"routing handler rename: expected at least two matches, found {occurrences}")
router.write_text(text.replace("handleDisplayTopologyChange", "handleDisplayRoutingChange"))
print(f"Applied: routing handler rename ({occurrences} references)")

replace_once(
    router,
    '''      let layoutOnly: CGDisplayChangeSummaryFlags = [
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
      Task { @MainActor in router.handleDisplayRoutingChange() }
''',
    '''      if flags.contains(.addFlag) || flags.contains(.removeFlag) {
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
''',
    "mode-aware display callback",
)

replace_once(
    router,
    '''    ) { [weak self] _ in
      Task { @MainActor in self?.scheduleOverlaySpaceSync() }
    }

    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification,
''',
    '''    ) { [weak self] _ in
      // This notification is the fallback for mode/mirror transitions whose Core Graphics flag
      // sequence varies by macOS release or adapter. Debouncing happens inside the routing path.
      Task { @MainActor in self?.handleDisplayRoutingChange() }
    }

    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification,
''',
    "screen-parameter routing fallback",
)

replace_once(
    router,
    '''  /// Remove stale rows and resources immediately, then debounce only the expensive reprobe so a
  /// burst of Core Graphics callbacks settles into one generation.
  private func handleDisplayRoutingChange() {
''',
    '''  /// Reconcile hot-plug, display-mode, and mirror-routing changes. Stale rows and resources are
  /// removed immediately; only the expensive capability reprobe is debounced.
  private func handleDisplayRoutingChange() {
''',
    "routing handler documentation",
)

replace_once(
    arm64,
    '''    let cpath = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_string_t>.size)
    defer { cpath.deallocate() }
    IORegistryEntryGetPath(entry, kIOServicePlane, cpath)
    ioregService.ioDisplayLocation = String(cString: cpath)
''',
    '''    let pathCapacity = MemoryLayout<io_string_t>.size
    let cpath = UnsafeMutablePointer<CChar>.allocate(capacity: pathCapacity)
    cpath.initialize(repeating: 0, count: pathCapacity)
    defer {
      cpath.deinitialize(count: pathCapacity)
      cpath.deallocate()
    }
    if IORegistryEntryGetPath(entry, kIOServicePlane, cpath) == KERN_SUCCESS {
      ioregService.ioDisplayLocation = String(cString: cpath)
    }
''',
    "initialized IORegistry path buffer",
)

replace_once(
    arm64,
    '''  static func setIORegServiceDCPAVServiceProxy(entry: io_service_t, ioregService: inout IOregService) {
    if let unmanagedLocation = IORegistryEntryCreateCFProperty(entry, "Location" as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)), let location = unmanagedLocation.takeRetainedValue() as? String {
      ioregService.location = location
      if location == "External" {
        ioregService.service = IOAVServiceCreateWithService(kCFAllocatorDefault, entry)?.takeRetainedValue() as IOAVService
      }
    }
  }
''',
    '''  static func setIORegServiceDCPAVServiceProxy(entry: io_service_t, ioregService: inout IOregService) {
    // Never carry a service handle from a previous proxy when this entry is internal or malformed.
    ioregService.location = ""
    ioregService.service = nil
    if let unmanagedLocation = IORegistryEntryCreateCFProperty(entry, "Location" as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)), let location = unmanagedLocation.takeRetainedValue() as? String {
      ioregService.location = location
      if location == "External" {
        ioregService.service = IOAVServiceCreateWithService(kCFAllocatorDefault, entry)?.takeRetainedValue() as IOAVService
      }
    }
  }
''',
    "clear stale IOAV proxy state",
)

replace_once(
    arm64,
    '''      } else if objectOfInterest.name == keyDCPAVServiceProxy {
        self.setIORegServiceDCPAVServiceProxy(entry: objectOfInterest.entry, ioregService: &ioregService)
        ioregServicesForMatching.append(ioregService)
      }
      IOObjectRelease(objectOfInterest.entry)
''',
    '''      } else if objectOfInterest.name == keyDCPAVServiceProxy {
        self.setIORegServiceDCPAVServiceProxy(entry: objectOfInterest.entry, ioregService: &ioregService)
        if ioregService.service != nil {
          ioregServicesForMatching.append(ioregService)
        }
        ioregService = IOregService()
      }
      IOObjectRelease(objectOfInterest.entry)
''',
    "append only valid external IOAV services",
)

print("Applied display-mode routing and IOKit safety fixes.")
