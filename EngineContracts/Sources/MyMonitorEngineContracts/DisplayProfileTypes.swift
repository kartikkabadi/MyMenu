public struct DisplayProfile: Equatable, Codable, Sendable {
  public let id: PersistentDisplayID
  public var nameOverride: String?
  public var desiredBrightness: DesiredBrightnessSet
  public var allowedRange: ClosedRange<NormalizedBrightness>
  public var requestedPreference: ControlPreference
  public var lastKnownMethod: DisplayControlMethod?

  public init(
    id: PersistentDisplayID,
    nameOverride: String? = nil,
    desiredBrightness: DesiredBrightnessSet = DesiredBrightnessSet(),
    allowedRange: ClosedRange<NormalizedBrightness> = .darkest ... .brightest,
    requestedPreference: ControlPreference = .automatic,
    lastKnownMethod: DisplayControlMethod? = nil
  ) {
    self.id = id
    self.nameOverride = nameOverride
    self.desiredBrightness = desiredBrightness
    self.allowedRange = allowedRange
    self.requestedPreference = requestedPreference
    self.lastKnownMethod = lastKnownMethod
  }
}

public struct DisplayProfileSnapshot: Equatable, Codable, Sendable {
  public let schemaVersion: Int
  public var profiles: [DisplayProfile]

  public init(schemaVersion: Int, profiles: [DisplayProfile]) {
    precondition(schemaVersion > 0, "Profile schema versions must be positive")
    self.schemaVersion = schemaVersion
    self.profiles = profiles
  }
}

public struct MigrationReport: Equatable, Codable, Sendable {
  public let sourceVersion: Int?
  public let targetVersion: Int
  public let migratedProfileCount: Int
  public let preservedLegacyRecordCount: Int
  public let warnings: [String]

  public init(
    sourceVersion: Int?,
    targetVersion: Int,
    migratedProfileCount: Int,
    preservedLegacyRecordCount: Int,
    warnings: [String]
  ) {
    self.sourceVersion = sourceVersion
    self.targetVersion = targetVersion
    self.migratedProfileCount = migratedProfileCount
    self.preservedLegacyRecordCount = preservedLegacyRecordCount
    self.warnings = warnings
  }
}
