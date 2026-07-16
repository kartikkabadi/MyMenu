import Foundation

/// Deterministic hardware-free states for SwiftUI previews, tests, and screenshot fixtures.
enum MonitorPresentationFixtures {
  static let studioDisplayID = MonitorID(rawValue: 1001)
  static let dellDisplayID = MonitorID(rawValue: 1002)
  static let projectorID = MonitorID(rawValue: 1003)
  static let unavailableDisplayID = MonitorID(rawValue: 1004)

  static let hardwareSnapshot = MonitorSnapshot(
    id: studioDisplayID,
    name: "Studio Display",
    brightness: 0.72,
    control: .available(.hardware)
  )

  static let softwareSnapshot = MonitorSnapshot(
    id: dellDisplayID,
    name: "Dell U2723QE",
    brightness: 0.55,
    control: .available(.software)
  )

  static let shadeSnapshot = MonitorSnapshot(
    id: projectorID,
    name: "Conference Room Projector",
    brightness: 0.41,
    control: .available(.shade)
  )

  static let checkingSnapshot = MonitorSnapshot(
    id: dellDisplayID,
    name: "Dell U2723QE",
    brightness: 0.55,
    control: .checking
  )

  static let unavailableSnapshot = MonitorSnapshot(
    id: unavailableDisplayID,
    name: "HDMI Display",
    brightness: nil,
    control: .unavailable(
      message: "MyMonitor could not adjust brightness through this connection.",
      canRetry: true
    )
  )

  static let longNameSnapshot = MonitorSnapshot(
    id: MonitorID(rawValue: 1005),
    name: "A Very Long External Display Name That Must Truncate Predictably",
    brightness: 0.88,
    control: .available(.hardware)
  )

  static let empty: DisplayControllerSnapshot = .ready([])
  static let detectingWithoutCache: DisplayControllerSnapshot = .detecting(cached: [])
  static let detecting: DisplayControllerSnapshot = .detecting(cached: [hardwareSnapshot])
  static let oneHardwareDisplay: DisplayControllerSnapshot = .ready([hardwareSnapshot])
  static let oneSoftwareDisplay: DisplayControllerSnapshot = .ready([softwareSnapshot])
  static let oneShadeDisplay: DisplayControllerSnapshot = .ready([shadeSnapshot])
  static let checkingControl: DisplayControllerSnapshot = .ready([checkingSnapshot])
  static let unavailableControl: DisplayControllerSnapshot = .ready([unavailableSnapshot])
  static let longNameDisplay: DisplayControllerSnapshot = .ready([longNameSnapshot])

  static let twoMixedDisplays: DisplayControllerSnapshot = .ready([
    hardwareSnapshot,
    shadeSnapshot,
  ])

  static let fourDisplays: DisplayControllerSnapshot = .ready([
    hardwareSnapshot,
    softwareSnapshot,
    shadeSnapshot,
    longNameSnapshot,
  ])

  static let eightDisplays: DisplayControllerSnapshot = .ready([
    hardwareSnapshot,
    softwareSnapshot,
    shadeSnapshot,
    longNameSnapshot,
    MonitorSnapshot(
      id: MonitorID(rawValue: 1006),
      name: "Portrait Display",
      brightness: 0.64,
      control: .available(.hardware)
    ),
    MonitorSnapshot(
      id: MonitorID(rawValue: 1007),
      name: "USB-C Travel Monitor",
      brightness: 0.36,
      control: .available(.software)
    ),
    MonitorSnapshot(
      id: MonitorID(rawValue: 1008),
      name: "Presentation Display",
      brightness: 0.79,
      control: .checking
    ),
    MonitorSnapshot(
      id: MonitorID(rawValue: 1009),
      name: "HDMI Capture Preview",
      brightness: nil,
      control: .unavailable(
        message: "Brightness is unavailable through this connection.",
        canRetry: true
      )
    ),
  ])

  static let failed: DisplayControllerSnapshot = .failed(
    message: "MyMonitor could not detect external displays.",
    canRetry: true
  )
}
