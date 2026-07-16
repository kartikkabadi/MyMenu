// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "MyMonitorPresentation",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "MyMonitorPresentation",
      targets: ["MyMonitorPresentation"]
    ),
  ],
  targets: [
    .target(
      name: "MyMonitorPolicies",
      path: "MyMonitor/Policies"
    ),
    .target(
      name: "MyMonitorEngineContracts",
      path: "EngineContracts/Sources/MyMonitorEngineContracts"
    ),
    .target(
      name: "MyMonitorPresentation",
      path: "MyMonitor/Presentation",
      exclude: [
        "DisplayRouterAdapter.swift",
      ],
      sources: [
        "MonitorPresentation.swift",
        "MonitorControlling.swift",
        "DisplayPresentationStore.swift",
        "DisplayPresentationStore+Keyboard.swift",
        "MonitorPresentationFixtures.swift",
        "LaunchAtLoginController.swift",
        "DisplayConfigurationPresentation.swift",
        "DisplayConfigurationControlling.swift",
        "DisplayConfigurationStore.swift",
        "KeyboardShortcutController.swift",
        "DiagnosticReport.swift",
      ]
    ),
    .testTarget(
      name: "MyMonitorPresentationTests",
      dependencies: [
        "MyMonitorPolicies",
        "MyMonitorPresentation",
      ],
      path: "MyMonitorTests/Presentation"
    ),
    .testTarget(
      name: "MyMonitorEngineContractsTests",
      dependencies: [
        "MyMonitorEngineContracts",
      ],
      path: "EngineContracts/Tests/MyMonitorEngineContractsTests"
    ),
  ],
  swiftLanguageVersions: [.v5]
)
