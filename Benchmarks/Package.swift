// swift-tools-version:6.0

import PackageDescription

let package = Package(
  name: "benchmarks",
  platforms: [
    .macOS("14")
  ],
  dependencies: [
    .package(path: ".."),
    .package(url: "https://github.com/ordo-one/package-benchmark", from: "1.4.0"),
  ],
  targets: [
    .executableTarget(
      name: "swift-composable-architecture-benchmark",
      dependencies: [
        .product(name: "Benchmark", package: "package-benchmark"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ],
      path: "Benchmarks/swift-composable-architecture-benchmark",
      plugins: [
        .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
      ]
    )
  ]
)
