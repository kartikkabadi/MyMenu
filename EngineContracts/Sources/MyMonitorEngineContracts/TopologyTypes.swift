public struct ConnectionEvidence: Equatable, Codable, Sendable {
  public let transport: String?
  public let supportID: String?
  public let portHint: String?

  public init(
    transport: String? = nil,
    supportID: String? = nil,
    portHint: String? = nil
  ) {
    self.transport = transport
    self.supportID = supportID
    self.portHint = portHint
  }
}

public struct RuntimeDisplayDescriptor: Equatable, Codable, Sendable {
  public let runtimeID: RuntimeDisplayID
  public let name: String
  public let isBuiltIn: Bool
  public let isOnline: Bool
  public let connection: ConnectionEvidence

  public init(
    runtimeID: RuntimeDisplayID,
    name: String,
    isBuiltIn: Bool,
    isOnline: Bool,
    connection: ConnectionEvidence = ConnectionEvidence()
  ) {
    self.runtimeID = runtimeID
    self.name = name
    self.isBuiltIn = isBuiltIn
    self.isOnline = isOnline
    self.connection = connection
  }
}

public struct DisplayMirrorGroup: Equatable, Codable, Sendable {
  public let id: DisplayGroupID
  public let members: [RuntimeDisplayID]
  public let isFullMirror: Bool

  public init(
    id: DisplayGroupID,
    members: [RuntimeDisplayID],
    isFullMirror: Bool
  ) {
    self.id = id
    self.members = members
    self.isFullMirror = isFullMirror
  }
}

public struct DisplayTopologySnapshot: Equatable, Codable, Sendable {
  public let capturedAt: EngineInstant
  public let signature: TopologySignature
  public let displays: [RuntimeDisplayDescriptor]
  public let mirrorGroups: [DisplayMirrorGroup]

  public init(
    capturedAt: EngineInstant,
    signature: TopologySignature,
    displays: [RuntimeDisplayDescriptor],
    mirrorGroups: [DisplayMirrorGroup]
  ) {
    self.capturedAt = capturedAt
    self.signature = signature
    self.displays = displays
    self.mirrorGroups = mirrorGroups
  }

  public var onlineDisplayIDs: Set<RuntimeDisplayID> {
    Set(displays.lazy.filter(\.isOnline).map(\.runtimeID))
  }

  public func descriptor(for runtimeID: RuntimeDisplayID) -> RuntimeDisplayDescriptor? {
    displays.first { $0.runtimeID == runtimeID }
  }
}
