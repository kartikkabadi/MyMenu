import CoreGraphics
import Foundation

private let ddcLuminanceVCP: UInt8 = 0x10

/// Successful side-effect-minimal DDC capability result for one display.
///
/// The connection is created and validated on the single global DDC queue. It may cross the main
/// actor only as an opaque handle; all I2C communication remains serialized by `DDCConnection`.
struct DDCProbeResult: @unchecked Sendable {
  let displayID: CGDirectDisplayID
  let currentBrightness: Double
  fileprivate let connection: DDCConnection

  func invalidate() {
    connection.invalidate()
  }
}

/// DDC/CI brightness for a single external display via Arm64DDC (VCP 0x10 luminance).
@MainActor
final class DDCBrightnessBackend: BrightnessBackend {
  static let tier: BrightnessTier = .ddc

  private let connection: DDCConnection

  required init(displayID: CGDirectDisplayID) {
    connection = DDCConnection(displayID: displayID)
  }

  init(probeResult: DDCProbeResult) {
    connection = probeResult.connection
  }

  /// Resolve and validate all requested DDC connections on the serialized worker queue.
  static func probe(
    displayIDs: [CGDirectDisplayID],
    completion: @escaping @MainActor ([CGDirectDisplayID: DDCProbeResult]) -> Void
  ) {
    DDCConnection.probe(displayIDs: displayIDs, completion: completion)
  }

  func setBrightness(_ value: Double, animated: Bool) {
    _ = animated
    connection.scheduleBrightness(value)
  }

  func teardown() {
    connection.invalidate()
  }
}

/// Owns all mutable DDC state and executes every service lookup/read/write on one serial queue.
private final class DDCConnection: @unchecked Sendable {
  fileprivate static let queue = DispatchQueue(
    label: "MyMonitor.globalDDC",
    qos: .userInitiated
  )
  private static let writeDebounceInterval: DispatchTimeInterval = .milliseconds(90)

  private let displayID: CGDirectDisplayID
  private var service: IOAVService?
  private var maximum: UInt16
  private var lastWritten: UInt16?
  private var pendingNormalized: Double?
  private var writeGeneration: UInt64 = 0
  private var invalidated = false

  init(
    displayID: CGDirectDisplayID,
    service: IOAVService? = nil,
    maximum: UInt16 = 100,
    current: UInt16? = nil
  ) {
    self.displayID = displayID
    self.service = service
    self.maximum = max(maximum, 1)
    lastWritten = current
  }

  static func probe(
    displayIDs: [CGDirectDisplayID],
    completion: @escaping @MainActor ([CGDirectDisplayID: DDCProbeResult]) -> Void
  ) {
    let uniqueIDs = Array(Set(displayIDs)).sorted()
    guard Arm64DDC.isArm64, !uniqueIDs.isEmpty else {
      DispatchQueue.main.async {
        completion([:])
      }
      return
    }

    queue.async {
      let matches = Arm64DDC.getServiceMatches(displayIDs: uniqueIDs)
      var results: [CGDirectDisplayID: DDCProbeResult] = [:]
      results.reserveCapacity(matches.count)

      for match in matches {
        guard !match.discouraged,
          !match.dummy,
          let service = match.service,
          let values = Arm64DDC.read(
            service: service,
            command: ddcLuminanceVCP
          )
        else {
          continue
        }

        let maximum = max(values.max, 1)
        let current = min(values.current, maximum)

        // Writing the exact current value validates the write path without changing luminance.
        guard Arm64DDC.write(
          service: service,
          command: ddcLuminanceVCP,
          value: current
        ),
          let reread = Arm64DDC.read(
            service: service,
            command: ddcLuminanceVCP
          ),
          abs(Int(reread.current) - Int(current)) <= 2
        else {
          continue
        }

        let connection = DDCConnection(
          displayID: match.displayID,
          service: service,
          maximum: maximum,
          current: reread.current
        )
        let normalized = min(
          max(Double(reread.current) / Double(maximum), 0),
          1
        )
        results[match.displayID] = DDCProbeResult(
          displayID: match.displayID,
          currentBrightness: normalized,
          connection: connection
        )
      }

      DispatchQueue.main.async {
        completion(results)
      }
    }
  }

  func scheduleBrightness(_ value: Double) {
    let normalized = min(max(value, 0), 1)

    Self.queue.async { [weak self] in
      guard let self, !self.invalidated else { return }

      self.pendingNormalized = normalized
      self.writeGeneration &+= 1
      let generation = self.writeGeneration

      Self.queue.asyncAfter(deadline: .now() + Self.writeDebounceInterval) { [weak self] in
        guard let self,
          !self.invalidated,
          generation == self.writeGeneration
        else {
          return
        }
        self.flushPendingWrite()
      }
    }
  }

  func invalidate() {
    Self.queue.async { [weak self] in
      guard let self else { return }
      self.invalidated = true
      self.writeGeneration &+= 1
      self.pendingNormalized = nil
      self.service = nil
      self.lastWritten = nil
    }
  }

  private func flushPendingWrite() {
    guard !invalidated, let normalized = pendingNormalized else { return }
    pendingNormalized = nil

    guard resolveServiceIfNeeded(), let service else { return }
    readRangeIfNeeded(service: service)

    let ddcValue = UInt16(round(normalized * Double(maximum)))
    guard ddcValue != lastWritten else { return }

    if Arm64DDC.write(
      service: service,
      command: ddcLuminanceVCP,
      value: ddcValue
    ) {
      lastWritten = ddcValue
    }
  }

  private func resolveServiceIfNeeded() -> Bool {
    if service != nil { return true }

    let matches = Arm64DDC.getServiceMatches(displayIDs: [displayID])
    guard let match = matches.first(where: { $0.displayID == displayID }),
      !match.discouraged,
      !match.dummy,
      let resolvedService = match.service
    else {
      return false
    }

    service = resolvedService
    return true
  }

  private func readRangeIfNeeded(service: IOAVService) {
    guard lastWritten == nil else { return }
    guard let values = Arm64DDC.read(
      service: service,
      command: ddcLuminanceVCP
    ) else {
      return
    }

    maximum = max(values.max, 1)
    lastWritten = values.current
  }
}
