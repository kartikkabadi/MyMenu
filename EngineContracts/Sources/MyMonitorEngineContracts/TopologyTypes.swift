import Foundation

struct ConnectionEvidence: Equatable, Codable, Sendable {
  let transport: String?
  let pathHash: String?
  let portHint: String?

  init(transport: String? = nil, pathHash: String? = nil, portHint: String? = nil) {
    self.transport = transport
    self.pathHash = pathHash
    self.portHint = portHint
  }
}

struct RuntimeDisplayDescriptor: Equatable, Codable, Sendable {
  let runtimeID: RuntimeDisplayID
  let name: String
  let isBuiltIn: Bool
  let isOnline: Bool
  let vendorID: UInt32?
  let productID: UInt32?
  let serialNumber: UInt32?
  let edidDigest: String?
  let connection: ConnectionEvidence
}

struct DisplayMirrorGroup: Equatable, Codable, Sendable {
  let id: DisplayGroupID
  let members: [RuntimeDisplayID]
  let isFullMirror: Bool
}

struct DisplayTopologySnapshot: Equatable, Codable, Sendable {
  let capturedAt: EngineInstant
  let signature: TopologySignature
  let displays: [RuntimeDisplayDescriptor]
  let mirrorGroups: [DisplayMirrorGroup]

  var onlineDisplayIDs: Set<RuntimeDisplayID> {
    Set(displays.lazy.filter(\.isOnline).map(\.runtimeID))
  }

  func descriptor(for runtimeID: RuntimeDisplayID) -> RuntimeDisplayDescriptor? {
    displays.first { $0.runtimeID == runtimeID }
  }
}
