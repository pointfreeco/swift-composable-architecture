// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "tic-tac-toe",
  platforms: [
    .iOS(.v14)
  ],
  products: [
    .library(name: "AppCore", targets: ["AppCore"]),
    .library(name: "AppSwiftUI", targets: ["AppSwiftUI"]),
    .library(name: "AppUIKit", targets: ["AppUIKit"]),
    .library(name: "AuthenticationClient", targets: ["AuthenticationClient"]),
    .library(name: "AuthenticationClientLive", targets: ["AuthenticationClientLive"]),
    .library(name: "GameCore", targets: ["GameCore"]),
    .library(name: "GameSwiftUI", targets: ["GameSwiftUI"]),
    .library(name: "GameUIKit", targets: ["GameUIKit"]),
    .library(name: "LoginCore", targets: ["LoginCore"]),
    .library(name: "LoginSwiftUI", targets: ["LoginSwiftUI"]),
    .library(name: "LoginUIKit", targets: ["LoginUIKit"]),
    .library(name: "NewGameCore", targets: ["NewGameCore"]),
    .library(name: "NewGameSwiftUI", targets: ["NewGameSwiftUI"]),
    .library(name: "NewGameUIKit", targets: ["NewGameUIKit"]),
    .library(name: "TwoFactorCore", targets: ["TwoFactorCore"]),
    .library(name: "TwoFactorSwiftUI", targets: ["TwoFactorSwiftUI"]),
    .library(name: "TwoFactorUIKit", targets: ["TwoFactorUIKit"]),
  ],
  dependencies: [
    .package(name: "swift-composable-architecture", path: "../../..")
  ],
  targets: [
    .target(
      name: "AppCore",
      dependencies: [
        "AuthenticationClient",
        "LoginCore",
        "NewGameCore",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "AppCoreTests",
      dependencies: ["AppCore"]
    ),
    .target(
      name: "AppSwiftUI",
      dependencies: [
        "AppCore",
        "LoginSwiftUI",
        "NewGameSwiftUI",
      ]
    ),
    .target(
      name: "AppUIKit",
      dependencies: [
        "AppCore",
        "LoginUIKit",
        "NewGameUIKit",
      ]
    ),

    .target(
      name: "AuthenticationClient",
      dependencies: [
        .product(name: "Dependencies", package: "swift-composable-architecture")
      ]
    ),
    .target(
      name: "AuthenticationClientLive",
      dependencies: ["AuthenticationClient"]
    ),

    .target(
      name: "GameCore",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
      ]
    ),
    .testTarget(
      name: "GameCoreTests",
      dependencies: ["GameCore"]
    ),
    .target(
      name: "GameSwiftUI",
      dependencies: ["GameCore"]
    ),
    .testTarget(
      name: "GameSwiftUITests",
      dependencies: ["GameSwiftUI"]
    ),
    .target(
      name: "GameUIKit",
      dependencies: ["GameCore"]
    ),

    .target(
      name: "LoginCore",
      dependencies: [
        "AuthenticationClient",
        "TwoFactorCore",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "LoginCoreTests",
      dependencies: ["LoginCore"]
    ),
    .target(
      name: "LoginSwiftUI",
      dependencies: [
        "LoginCore",
        "TwoFactorSwiftUI",
      ]
    ),
    .testTarget(
      name: "LoginSwiftUITests",
      dependencies: ["LoginSwiftUI"]
    ),
    .target(
      name: "LoginUIKit",
      dependencies: [
        "LoginCore",
        "TwoFactorUIKit",
      ]
    ),

    .target(
      name: "NewGameCore",
      dependencies: [
        "GameCore",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "NewGameCoreTests",
      dependencies: ["NewGameCore"]
    ),
    .target(
      name: "NewGameSwiftUI",
      dependencies: [
        "GameSwiftUI",
        "NewGameCore",
      ]
    ),
    .testTarget(
      name: "NewGameSwiftUITests",
      dependencies: ["NewGameSwiftUI"]
    ),
    .target(
      name: "NewGameUIKit",
      dependencies: [
        "GameUIKit",
        "NewGameCore",
      ]
    ),

    .target(
      name: "TwoFactorCore",
      dependencies: [
        "AuthenticationClient",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "TwoFactorCoreTests",
      dependencies: ["TwoFactorCore"]
    ),
    .target(
      name: "TwoFactorSwiftUI",
      dependencies: ["TwoFactorCore"]
    ),
    .testTarget(
      name: "TwoFactorSwiftUITests",
      dependencies: ["TwoFactorSwiftUI"]
    ),
    .target(
      name: "TwoFactorUIKit",
      dependencies: ["TwoFactorCore"]
    ),
  ]
)

for target in package.targets {
  target.swiftSettings = [
    .unsafeFlags([
      "-Xfrontend", "-enable-actor-data-race-checks",
      "-Xfrontend", "-warn-concurrency",
    ])
  ]
}
