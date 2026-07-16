import Foundation

struct DisplayProfile: Equatable, Codable, Sendable {
  let id: PersistentDisplayID
  var nameOverride: String?
  var desiredBrightness: DesiredBrightnessSet
  var allowedRange: ClosedRange<NormalizedBrightness>
  var requestedPreference: ControlPreference
  var lastKnownMethod: DisplayControlMethod?

  init(
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

struct DisplayProfileSnapshot: Equatable, Codable, Sendable {
  let schemaVersion: Int
  var profiles: [DisplayProfile]

  init(schemaVersion: Int, profiles: [DisplayProfile]) {
    precondition(schemaVersion > 0, "Profile schema versions must be positive")
    self.schemaVersion = schemaVersion
    self.profiles = profiles
  }
}

struct MigrationReport: Equatable, Codable, Sendable {
  let sourceVersion: Int?
  let targetVersion: Int
  let migratedProfileCount: Int
  let preservedLegacyRecordCount: Int
  let warnings: [String]
}
