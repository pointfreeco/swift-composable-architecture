// swift-tools-version:5.1

import PackageDescription

let package = Package(
  name: "rx-swift-composable-architecture",
  platforms: [
    .iOS(.v12),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(
      name: "ComposableArchitecture",
      targets: ["ComposableArchitecture"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "0.1.1"),
    .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "5.0.0")
  ],
  targets: [
    .target(
      name: "ComposableArchitecture",
      dependencies: [
        "CasePaths", "RxSwift", "RxCocoa"
      ]
    ),
    .testTarget(
      name: "ComposableArchitectureTests",
      dependencies: [
        "ComposableArchitecture",
      ]
    )
  ]
)
