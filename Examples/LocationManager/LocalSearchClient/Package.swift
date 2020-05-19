// swift-tools-version:5.1

import PackageDescription

let package = Package(
  name: "LocalSearchClient",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    // Products define the executables and libraries produced by a package, and make them visible to other packages.
    .library(
      name: "LocalSearchClient",
      targets: ["LocalSearchClient"]),
  ],
  dependencies: [
    // Dependencies declare other packages that this package depends on.
    // .package(url: /* package url */, from: "1.0.0"),
    .package(path: "../../../")
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .target(
      name: "LocalSearchClient",
      dependencies: ["ComposableArchitecture"]),
  ]
)
