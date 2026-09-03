// swift-tools-version: 6.4

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "swift-composable-architecture",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: [
    .library(
      name: "ComposableArchitecture",
      targets: ["ComposableArchitecture"]
    )
  ],
  traits: [
    .trait(
      name: "ComposableArchitecture2Deprecations",
      description: """
        Prepare for the next major release by enabling some of the more viral deprecations. Enable \
        this trait to remain ready for Composable Architecture 2.0.
        """
    ),
    .trait(
      name: "ComposableArchitecture2DeprecationOverloads",
      description: """
        Prepare for the next major release by enabling some of the more viral deprecations. These \
        deprecations rely on overloads that can tax the compiler and prevent existing applications \
        from compiling. Temporarily enable this trait to perform these specific migrations.
        """
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-collections", from: "1.1.0"),
    .package(url: "https://github.com/pointfreeco/combine-schedulers", from: "1.2.2"),
    .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "1.10.0"),
    .package(url: "https://github.com/pointfreeco/swift-clocks", from: "1.1.1"),
    .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.4.1"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.7.3"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.1"),
    .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.1.1"),
    .package(url: "https://github.com/pointfreeco/swift-issue-reporting", from: "2.1.0"),
    .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.7.0"),
    .package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.11.2"),
    .package(url: "https://github.com/pointfreeco/swift-perception", "2.0.12"..<"3.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-sharing", "2.10.1"..<"3.0.0"),
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax", "509.0.0"..<"605.0.0"),
  ],
  targets: [
    .target(
      name: "ComposableArchitecture",
      dependencies: [
        "ComposableArchitectureMacros",
        .product(name: "CasePaths", package: "swift-case-paths"),
        .product(name: "Clocks", package: "swift-clocks"),
        .product(name: "CombineSchedulers", package: "combine-schedulers"),
        .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
        .product(name: "IssueReporting", package: "swift-issue-reporting"),
        .product(name: "OrderedCollections", package: "swift-collections"),
        .product(name: "Perception", package: "swift-perception"),
        .product(name: "Sharing", package: "swift-sharing"),
        .product(name: "SwiftUINavigation", package: "swift-navigation"),
        .product(name: "UIKitNavigation", package: "swift-navigation"),
      ],
      resources: [
        .process("Resources/PrivacyInfo.xcprivacy")
      ]
    ),
    .testTarget(
      name: "ComposableArchitectureTests",
      dependencies: [
        "ComposableArchitecture",
        .product(name: "IssueReportingTestSupport", package: "swift-issue-reporting"),
      ]
    ),
    .macro(
      name: "ComposableArchitectureMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "ComposableArchitectureMacrosTests",
      dependencies: [
        "ComposableArchitectureMacros",
        .product(name: "MacroTesting", package: "swift-macro-testing"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)

for target in package.targets {
  target.swiftSettings = target.swiftSettings ?? []
  target.swiftSettings?.append(contentsOf: [
    .enableUpcomingFeature("ExistentialAny")
  ])
}

for target in package.targets where target.type == .system || target.type == .test {
  target.swiftSettings?.append(contentsOf: [
    .swiftLanguageMode(.v5),
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("InferSendableFromCaptures"),
  ])
}
