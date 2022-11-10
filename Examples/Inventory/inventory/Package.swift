// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "inventory",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "Item", targets: ["Item"]),
        .library(name: "ItemRow", targets: ["ItemRow"]),
        .library(name: "InventoryFeature", targets: ["InventoryFeature"]),
        .library(name: "AppFeature", targets: ["AppFeature"]),
    ],
    dependencies: [
        .package(name: "swift-composable-architecture", path: "../../.."),
        .package(url: "https://github.com/pointfreeco/swiftui-navigation.git", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "Item",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "ItemRow",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SwiftUINavigation", package: "swiftui-navigation"),
                .target(name: "Item"),
            ]
        ),
        .target(
            name: "InventoryFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .target(name: "ItemRow"),
            ]
        ),
        .target(
            name: "AppFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .target(name: "InventoryFeature"),
            ]
        ),
//        .testTarget(
//            name: "inventoryTests",
//            dependencies: ["inventory"]),
    ]
)
