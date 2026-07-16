# Durable Display Identity and Persistence

This document defines how MyMonitor distinguishes runtime displays, persistent physical monitors, connection paths, logical groups, and saved profiles.

## 1. Identity problem

`CGDirectDisplayID` is a runtime handle. It is required for Core Graphics and AppKit calls, but it is not the persistent identity MyMonitor should use for preferences.

A monitor may receive different runtime IDs when:

- the Mac restarts;
- the app restarts after topology changes;
- the monitor moves between ports;
- a dock or adapter changes;
- mirroring changes;
- Picture-by-Picture is enabled;
- macOS rebuilds the display graph.

Conversely, one physical monitor may expose multiple logical displays or IOAV candidates.

The identity system must distinguish these concepts instead of forcing them into one integer.

## 2. Identity layers

## 2.1 Runtime display identity

```swift
struct RuntimeDisplayID: Hashable, Sendable {
  let rawValue: CGDirectDisplayID
}
```

Properties:

- valid only for a captured topology generation;
- used for Core Graphics, `NSScreen`, Gamma, and Shade;
- never used directly as a durable profile key;
- included in internal diagnostics only as ephemeral evidence.

## 2.2 Persistent physical fingerprint

```swift
struct DisplayFingerprint: Hashable, Codable, Sendable {
  let vendorID: UInt32?
  let productID: UInt32?
  let numericSerial: UInt32?
  let alphanumericSerial: String?
  let edidDigest: String?
  let manufactureWeek: UInt8?
  let manufactureYear: UInt16?
  let physicalWidthMM: UInt16?
  let physicalHeightMM: UInt16?
  let normalizedProductName: String?
}
```

Rules:

- zero or empty serial values are treated as absent;
- raw EDID bytes are not used as the public/profile ID string;
- the stored fingerprint may contain local raw fields needed for matching, but exported diagnostics use redacted support IDs;
- product name is weak evidence and never sufficient alone;
- physical size and manufacture data are weak tie-breakers;
- private IORegistry evidence is optional, not assumed.

## 2.3 Connection identity

```swift
struct DisplayConnectionPath: Hashable, Codable, Sendable {
  let ioDisplayLocationDigest: String?
  let upstreamTransport: String?
  let downstreamTransport: String?
  let serviceLocation: Int?
  let portSlot: String?
}
```

Connection identity helps distinguish identical monitors and match IOAV services. It is not the primary physical fingerprint because moving a cable must not create a new monitor profile when stronger evidence exists.

## 2.4 Persistent profile identity

```swift
struct PersistentDisplayID: Hashable, Codable, Sendable {
  let rawValue: String
}
```

Construction priority:

1. namespace + vendor + product + trustworthy nonzero serial;
2. namespace + EDID digest;
3. namespace + stable composite fingerprint;
4. namespace + composite fingerprint + connection slot for ambiguous duplicates;
5. random local UUID when no deterministic identity is safe.

The exact hash format is versioned and internal. Never parse product behavior from the string.

## 2.5 Logical target identity

A logical target can represent:

- one physical external display;
- one full mirror group;
- one shared physical backlight exposed by multiple logical displays.

```swift
enum LogicalDisplayTargetID: Hashable, Sendable {
  case display(PersistentDisplayID)
  case mirrorGroup(MirrorSetID)
  case sharedControl(PhysicalControlResourceID)
}
```

Frontend rows use logical target IDs. Profiles remain attached to physical display IDs, with group state derived from members.

## 3. Evidence sources

## 3.1 Public Core Graphics evidence

Preferred public values:

- `CGDisplayVendorNumber`;
- `CGDisplayModelNumber`;
- `CGDisplaySerialNumber`;
- physical size where available;
- runtime display UUID where useful as secondary evidence;
- built-in/external status;
- mirror-set membership.

Public values can still be zero, duplicated, or unstable for virtual/dongle paths.

## 3.2 IORegistry/EDID evidence

Optional adapter evidence:

- EDID UUID/digest;
- manufacturer ID;
- product name;
- numeric and alphanumeric serial;
- IO display location;
- upstream/downstream transport;
- DCPAV service location.

This evidence is gathered behind the private/IOKit adapter boundary. The identity resolver consumes MyMonitor-owned values.

## 3.3 AppKit evidence

`NSScreen.localizedName` is presentation metadata, not identity. It may be localized, generic, duplicated, or change across macOS versions.

## 4. Match confidence

Every match includes confidence and rationale.

```swift
enum IdentityMatchConfidence: Int, Codable, Sendable {
  case exact
  case high
  case medium
  case low
  case ambiguous
  case new
}

struct IdentityMatchResult: Sendable {
  let runtimeID: RuntimeDisplayID
  let persistentID: PersistentDisplayID
  let confidence: IdentityMatchConfidence
  let evidence: [IdentityEvidence]
  let alternatives: [PersistentDisplayID]
}
```

### Exact

- vendor/product/nonzero serial match, or
- exact EDID digest with no contradiction.

### High

- strong composite fingerprint plus compatible connection evidence;
- one unique candidate.

### Medium

- composite weak fingerprint uniquely matches one saved profile;
- no serial or EDID.

### Low

- connection slot is doing most of the work;
- behavior may change when cables move.

### Ambiguous

- multiple profiles are equally plausible;
- engine must not merge or auto-restore saved brightness.

### New

- no candidate profile.

## 5. Matching algorithm

For each runtime display:

1. Build the strongest available fingerprint.
2. Exclude built-in displays from MyMonitor profile creation.
3. Search exact nonzero serial + vendor/product.
4. Search exact EDID digest.
5. Score composite candidates:
   - vendor/product;
   - manufacture date;
   - physical dimensions;
   - normalized product name;
   - connection compatibility.
6. Resolve globally, not greedily per display, so one saved profile cannot match two current displays.
7. Prefer the assignment with highest total confidence.
8. If two assignments remain equivalent, mark ambiguous.
9. Create a new profile only after the global assignment.

The algorithm must be pure and deterministic for one topology snapshot.

## 6. Duplicate identical displays

Two monitors may have:

- the same vendor/product;
- serial `0`;
- identical EDID;
- identical name and physical size.

MyMonitor cannot invent physical identity.

Policy:

- distinguish current instances using connection path slots;
- store that the profile is connection-bound;
- do not auto-restore brightness after a cable/port swap when confidence is low;
- expose a privacy-safe warning in diagnostics;
- allow future Settings UI to rename the displays;
- never silently merge their profiles.

If the user swaps two indistinguishable monitors between ports, connection-bound settings may follow the port. This is a documented limitation, not a hidden promise.

## 7. Picture-by-Picture and shared controls

A Picture-by-Picture monitor can expose two runtime displays while DDC changes one shared physical backlight.

Detection evidence:

- two runtime displays map to the same IOAV service/resource ID;
- writes to one are observed on both;
- model/serial fingerprints are identical;
- service matching cannot assign unique physical resources.

Initial policy:

- create one `PhysicalControlResourceID`;
- serialize through one control session;
- logical rows may share observed state or be collapsed based on product behavior;
- never run two independent DDC writers against the same service;
- diagnostics report shared-control grouping without raw service details.

## 8. Display profile

```swift
struct DesiredBrightnessProfile: Codable, Equatable, Sendable {
  var hardware: Double?
  var gamma: Double?
  var shade: Double?
  var legacyUnscoped: Double?
}

struct DisplayProfile: Codable, Equatable, Sendable {
  let schemaVersion: Int
  let id: PersistentDisplayID
  var fingerprint: DisplayFingerprint
  var connectionHistory: [DisplayConnectionPath]
  var userName: String?
  var lastSystemName: String
  var desiredBrightness: DesiredBrightnessProfile
  var allowedRange: ClosedRange<Double>
  var requestedPreference: ControlPreference
  var lastActiveMethod: DisplayControlMethod?
  var identityConfidence: IdentityMatchConfidence
  var createdAt: Date
  var updatedAt: Date
}
```

Additional internal migration fields are allowed. Do not turn the profile into a general monitor database.

## 9. Storage format

The first target implementation uses a versioned Codable snapshot stored locally through `DisplayProfileStore`.

Recommended shape:

```swift
struct DisplayProfileSnapshot: Codable, Sendable {
  let schemaVersion: Int
  var profiles: [PersistentDisplayID: DisplayProfile]
  var legacyMappings: [UInt32: PersistentDisplayID]
  var installSalt: Data
}
```

`UserDefaults` is acceptable for this small preference dataset if:

- all keys are hidden behind the store;
- the entire snapshot is versioned;
- decode failure is non-destructive;
- writes are atomic from the caller’s perspective;
- tests use an in-memory store;
- migration is idempotent.

A database is unnecessary.

## 10. Privacy-safe support identity

Diagnostics use a support ID derived from persistent identity with a per-install salt:

```text
Display A7F2-19C4
```

Requirements:

- stable inside one installation;
- not reversible to serial/EDID without local profile data;
- short enough for support communication;
- different across installations;
- never used as the actual matching key.

## 11. Legacy v2 migration

Current v2 storage is keyed by `CGDirectDisplayID` and includes:

- brightness;
- minimum/maximum brightness;
- control preference;
- name;
- tier;
- known display IDs.

Migration occurs when a runtime display is connected and can be matched.

### Migration steps

1. Load legacy known IDs and keys without deleting them.
2. Capture the current topology and fingerprint.
3. If current runtime ID has legacy values, create or update the matched v3 profile.
4. Copy:
   - saved desired brightness into the domain implied by trustworthy legacy tier/method evidence;
   - otherwise preserve it as `legacyUnscoped` without automatic application;
   - range;
   - requested preference;
   - saved name;
   - last tier as diagnostic history only.
5. Record `legacyRuntimeID → PersistentDisplayID`.
6. Mark that legacy record migrated.
7. Preserve legacy data until a later cleanup version or explicit Forget action.

### Migration behavior

- migration never writes hardware;
- migrated desired brightness does not override readable hardware on cold launch;
- rerunning migration produces the same result;
- ambiguous identity does not consume a legacy record;
- disconnected legacy records remain available for future mapping;
- Forget removes both the v3 profile and mapped legacy keys for that profile.

## 12. Profile merge and split

The initial release does not expose automatic profile merge/split UI.

Engine rules:

- exact evidence may upgrade a low-confidence profile;
- two existing profiles are not automatically merged merely because one topology maps them to the same model;
- one existing profile may split only through explicit migration logic with evidence and tests;
- conflicts preserve both records and record a diagnostic event.

## 13. Sorting and naming

Stable presentation order is based on:

1. user-defined order in a future schema, when available;
2. prior stable profile order for known displays;
3. system name;
4. persistent ID as deterministic tie-breaker.

Name priority:

1. user override;
2. current `NSScreen.localizedName`;
3. last system name;
4. generic “External Display”.

Names never determine identity alone.

## 14. Forget behavior

Forgetting a display:

- removes the v3 profile;
- removes mapped v2 keys;
- removes all per-domain and legacy-unscoped desired brightness, range, name, and preference;
- removes hotkey target references to the persistent ID;
- does not change current physical brightness;
- resets a currently connected session to default profile values;
- triggers method re-resolution only when the removed preference changes eligibility;
- records a local diagnostic event without retaining deleted identity details.

## 15. Tests

Required pure tests:

- exact serial match;
- exact EDID match;
- serial zero treated as absent;
- unique composite match;
- ambiguous identical pair;
- global assignment prevents one profile matching two displays;
- port move preserves high-confidence physical profile;
- low-confidence duplicate follows connection slot;
- PBP runtime displays share one physical resource;
- migration is idempotent;
- legacy tier maps desired brightness to the correct domain;
- unknown legacy tier preserves an unscoped value without applying it;
- migration never changes observed/desired engine state directly;
- legacy ambiguous record remains untouched;
- Forget removes v2 and v3 state;
- diagnostic support IDs are stable per install and differ across salts;
- raw serial/EDID/path never appears in exported diagnostic fixtures.

## 16. Rejected identity strategies

### Raw `CGDirectDisplayID`

Rejected for persistence; retained only for runtime calls.

### Display name

Rejected as non-unique and mutable.

### EDID only

Rejected as some monitors expose zero, duplicate, missing, or adapter-modified EDID.

### Connection path only

Rejected as it makes settings follow ports instead of monitors.

### User-visible manual pairing as the default

Rejected. Most displays should match automatically. Manual disambiguation is a future fallback for genuinely indistinguishable hardware, not the first-run experience.
