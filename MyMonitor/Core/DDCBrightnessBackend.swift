import CoreGraphics
import Foundation

private let ddcLuminanceVCP: UInt8 = 0x10

/// DDC/CI brightness for a single external display via Arm64DDC (VCP 0x10 luminance).
@MainActor
final class DDCBrightnessBackend: BrightnessBackend {
  static let tier: BrightnessTier = .ddc

  private static let globalDDCQueue = DispatchQueue(label: "MyMonitor.globalDDC")
  private static let writeDebounceInterval: DispatchTimeInterval = .milliseconds(90)

  private let displayID: CGDirectDisplayID
  private var avService: IOAVService?
  private var maxDDCValue: UInt16 = 100
  private var lastWrittenDDC: UInt16?
  private var hasReadRange = false

  private var pendingNormalized: Double?
  private var debounceWorkItem: DispatchWorkItem?

  init(displayID: CGDirectDisplayID) {
    self.displayID = displayID
  }

  static func probe(displayID: CGDirectDisplayID) -> Bool {
    DDCBrightnessBackend(displayID: displayID).probeConnection()
  }

  /// Read the monitor's current hardware luminance without changing it.
  static func currentBrightness(displayID: CGDirectDisplayID) -> Double? {
    let backend = DDCBrightnessBackend(displayID: displayID)
    backend.resolveServiceIfNeeded()
    guard let service = backend.avService else { return nil }

    var result: Double?
    globalDDCQueue.sync {
      guard let values = Arm64DDC.read(service: service, command: ddcLuminanceVCP) else { return }
      let maximum = max(values.max, 1)
      result = min(max(Double(values.current) / Double(maximum), 0), 1)
    }
    return result
  }

  private func probeConnection() -> Bool {
    guard Arm64DDC.isArm64 else { return false }
    resolveServiceIfNeeded()
    guard let service = avService else { return false }

    var success = false
    Self.globalDDCQueue.sync {
      guard let values = Arm64DDC.read(service: service, command: ddcLuminanceVCP) else { return }
      maxDDCValue = max(values.max, 1)
      let currentValue = values.current
      guard Arm64DDC.write(service: service, command: ddcLuminanceVCP, value: currentValue) else { return }
      guard let reread = Arm64DDC.read(service: service, command: ddcLuminanceVCP) else { return }
      success = abs(Int(reread.current) - Int(currentValue)) <= 2
    }
    return success
  }

  func setBrightness(_ value: Double, animated: Bool) {
    _ = animated
    pendingNormalized = min(max(value, 0), 1)
    debounceWorkItem?.cancel()

    let work = DispatchWorkItem { [weak self] in
      self?.flushPendingWrite()
    }
    debounceWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.writeDebounceInterval, execute: work)
  }

  func teardown() {
    debounceWorkItem?.cancel()
    debounceWorkItem = nil
    pendingNormalized = nil
    avService = nil
    lastWrittenDDC = nil
    hasReadRange = false
  }

  // MARK: - Private

  private func resolveServiceIfNeeded() {
    guard avService == nil else { return }
    let matches = Arm64DDC.getServiceMatches(displayIDs: [displayID])
    guard let match = matches.first(where: { $0.displayID == displayID }),
          !match.discouraged,
          !match.dummy,
          let service = match.service
    else {
      return
    }
    avService = service
  }

  private func readRangeIfNeeded(service: IOAVService) {
    guard !hasReadRange else { return }
    hasReadRange = true

    Self.globalDDCQueue.sync {
      guard let values = Arm64DDC.read(service: service, command: ddcLuminanceVCP) else { return }
      maxDDCValue = max(values.max, 1)
      lastWrittenDDC = values.current
    }
  }

  private func flushPendingWrite() {
    guard let normalized = pendingNormalized else { return }
    pendingNormalized = nil
    resolveServiceIfNeeded()
    guard let service = avService else { return }

    readRangeIfNeeded(service: service)

    // User-facing brightness is direct: 0 = darkest, 1 = brightest.
    let ddcValue = UInt16(round(normalized * Double(maxDDCValue)))
    guard ddcValue != lastWrittenDDC else { return }

    Self.globalDDCQueue.async { [weak self, service] in
      let ok = Arm64DDC.write(service: service, command: ddcLuminanceVCP, value: ddcValue)
      if ok {
        Task { @MainActor in
          self?.lastWrittenDDC = ddcValue
        }
      }
    }
  }
}
