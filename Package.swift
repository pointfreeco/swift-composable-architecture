// swift-tools-version:5.1

import PackageDescription

let package = Package(
  name: "swift-composable-architecture",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(
      name: "ComposableArchitecture",
      type: .dynamic,
      targets: ["ComposableArchitecture"]
    ),
    .library(
      name: "ComposableArchitectureTestSupport",
      type: .dynamic,
      targets: ["ComposableArchitectureTestSupport"]
    ),
  ],
  targets: [
    .target(
      name: "ComposableArchitecture",
      dependencies: [
      ]
    ),
    .testTarget(
      name: "ComposableArchitectureTests",
      dependencies: [
        "ComposableArchitecture",
        "ComposableArchitectureTestSupport",
      ]
    ),
    .target(
      name: "ComposableArchitectureTestSupport",
      dependencies: [
        "ComposableArchitecture",
      ]
    ),
  ]
)
