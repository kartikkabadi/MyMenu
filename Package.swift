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
      name: "MyMonitorPresentation",
      path: "MyMonitor/Presentation",
      sources: [
        "MonitorPresentation.swift",
        "MonitorControlling.swift",
        "DisplayPresentationStore.swift",
        "MonitorPresentationFixtures.swift",
      ]
    ),
    .testTarget(
      name: "MyMonitorPresentationTests",
      dependencies: ["MyMonitorPresentation"],
      path: "MyMonitorTests/Presentation"
    ),
  ],
  swiftLanguageVersions: [.v5]
)
