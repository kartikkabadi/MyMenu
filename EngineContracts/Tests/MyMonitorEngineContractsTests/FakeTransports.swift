import Foundation
@testable import MyMonitorEngineContracts

actor FakeAppleNativeTransport: AppleNativeTransport {
  struct Write: Equatable, Sendable {
    let display: RuntimeDisplayID
    let value: NormalizedBrightness
  }

  private var capabilityByDisplay: [RuntimeDisplayID: AppleNativeCapability] = [:]
  private var brightnessByDisplay: [RuntimeDisplayID: NormalizedBrightness] = [:]
  private var writeFailure: ControlFailure?
  private var writeTrace: [Write] = []

  func configureCapability(_ capability: AppleNativeCapability, for display: RuntimeDisplayID) {
    capabilityByDisplay[display] = capability
  }

  func configureBrightness(_ brightness: NormalizedBrightness, for display: RuntimeDisplayID) {
    brightnessByDisplay[display] = brightness
  }

  func configureWriteFailure(_ failure: ControlFailure?) {
    writeFailure = failure
  }

  func recordedWrites() -> [Write] {
    writeTrace
  }

  func capability(for display: RuntimeDisplayID) async -> AppleNativeCapability {
    capabilityByDisplay[display] ?? .unavailable(nil)
  }

  func readBrightness(for display: RuntimeDisplayID) async throws -> NormalizedBrightness {
    guard let value = brightnessByDisplay[display] else {
      throw ControlFailure.capabilityUnavailable(.appleNative)
    }
    return value
  }

  func writeBrightness(_ value: NormalizedBrightness, for display: RuntimeDisplayID) async throws {
    if let writeFailure {
      throw writeFailure
    }
    writeTrace.append(Write(display: display, value: value))
    brightnessByDisplay[display] = value
  }
}

actor FakeIOAVTransport: IOAVTransport {
  struct Write: Equatable, Sendable {
    let code: UInt8
    let value: UInt16
    let service: DDCServiceID
  }

  private var candidates: [DDCServiceCandidate] = []
  private var valueByService: [DDCServiceID: DDCValue] = [:]
  private var discoveryFailure: ControlFailure?
  private var readFailure: ControlFailure?
  private var writeFailure: ControlFailure?
  private var writeTrace: [Write] = []
  private var invalidationTrace: [DDCServiceID] = []

  func configureCandidates(_ candidates: [DDCServiceCandidate]) {
    self.candidates = candidates
  }

  func configureValue(_ value: DDCValue, for service: DDCServiceID) {
    valueByService[service] = value
  }

  func configureFailures(
    discovery: ControlFailure? = nil,
    read: ControlFailure? = nil,
    write: ControlFailure? = nil
  ) {
    discoveryFailure = discovery
    readFailure = read
    writeFailure = write
  }

  func recordedWrites() -> [Write] {
    writeTrace
  }

  func invalidatedServices() -> [DDCServiceID] {
    invalidationTrace
  }

  func discoverServices(for snapshot: DisplayTopologySnapshot) async throws -> [DDCServiceCandidate] {
    if let discoveryFailure {
      throw discoveryFailure
    }
    return candidates
  }

  func readVCP(_ code: UInt8, service: DDCServiceID) async throws -> DDCValue {
    if let readFailure {
      throw readFailure
    }
    guard code == 0x10, let value = valueByService[service] else {
      throw ControlFailure.invalidResponse
    }
    return value
  }

  func writeVCP(_ code: UInt8, value: UInt16, service: DDCServiceID) async throws {
    if let writeFailure {
      throw writeFailure
    }
    writeTrace.append(Write(code: code, value: value, service: service))
  }

  func invalidate(service: DDCServiceID) async {
    invalidationTrace.append(service)
  }
}

actor FakeDisplayProfileStore: DisplayProfileStoring {
  private var snapshot: DisplayProfileSnapshot
  private var migrationReport: MigrationReport
  private var failure: ControlFailure?
  private var saveTrace: [DisplayProfileSnapshot] = []

  init(
    snapshot: DisplayProfileSnapshot,
    migrationReport: MigrationReport
  ) {
    self.snapshot = snapshot
    self.migrationReport = migrationReport
  }

  func configureFailure(_ failure: ControlFailure?) {
    self.failure = failure
  }

  func savedSnapshots() -> [DisplayProfileSnapshot] {
    saveTrace
  }

  func loadSnapshot() async throws -> DisplayProfileSnapshot {
    if let failure { throw failure }
    return snapshot
  }

  func saveSnapshot(_ snapshot: DisplayProfileSnapshot) async throws {
    if let failure { throw failure }
    self.snapshot = snapshot
    saveTrace.append(snapshot)
  }

  func migrateLegacyIfNeeded(topology: DisplayTopologySnapshot) async throws -> MigrationReport {
    if let failure { throw failure }
    return migrationReport
  }
}

final class FakeDisplayTopologyProvider: DisplayTopologyProviding, @unchecked Sendable {
  private let lock = NSLock()
  private var snapshotsByReason: [ReconfigurationReason: DisplayTopologySnapshot] = [:]
  private var fallbackSnapshot: DisplayTopologySnapshot
  private var continuation: AsyncStream<DisplayTopologyEvent>.Continuation?

  init(snapshot: DisplayTopologySnapshot) {
    fallbackSnapshot = snapshot
  }

  func configureSnapshot(_ snapshot: DisplayTopologySnapshot, for reason: ReconfigurationReason) async {
    lock.withLock {
      snapshotsByReason[reason] = snapshot
    }
  }

  func snapshot(reason: ReconfigurationReason) async throws -> DisplayTopologySnapshot {
    lock.withLock {
      snapshotsByReason[reason] ?? fallbackSnapshot
    }
  }

  func events() -> AsyncStream<DisplayTopologyEvent> {
    AsyncStream { continuation in
      lock.withLock {
        self.continuation?.finish()
        self.continuation = continuation
      }
    }
  }

  func send(_ event: DisplayTopologyEvent) async {
    let continuation = lock.withLock { self.continuation }
    continuation?.yield(event)
  }

  func finish() async {
    let continuation = lock.withLock {
      defer { self.continuation = nil }
      return self.continuation
    }
    continuation?.finish()
  }
}
