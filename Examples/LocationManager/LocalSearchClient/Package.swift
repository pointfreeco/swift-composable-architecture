// swift-tools-version:5.1

import PackageDescription

let package = Package(
  name: "Common",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(
      name: "LocalSearchClient",
      targets: ["LocalSearchClient"]),
    .library(
      name: "LocationManagerCore",
      targets: ["LocationManagerCore"]),
  ],
  dependencies: [
    .package(path: "../../../")
  ],
  targets: [
    .target(
      name: "LocalSearchClient",
      dependencies: ["ComposableArchitecture"]),
    .target(
      name: "LocationManagerCore",
      dependencies: ["ComposableArchitecture", "ComposableCoreLocation", "LocalSearchClient"]),
    .testTarget(
      name: "LocationManagerCoreTests",
      dependencies: ["LocationManagerCore"]),
  ]
)
