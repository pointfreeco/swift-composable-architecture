load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SwiftUINavigationCore",
    srcs = glob(
        ["Sources/SwiftUINavigationCore/**/*.swift"],
    ),
    deps = [
        "@swift_custom_dump//:CustomDump",
        "@xctest_dynamic_overlay//:XCTestDynamicOverlay",
    ],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "SwiftUINavigation",
    srcs = glob(
        ["Sources/SwiftUINavigation/**/*.swift"],
    ),
    deps = [
        ":SwiftUINavigationCore",
        "@swift_case_paths//:CasePaths",
    ],
    visibility = ["//visibility:public"],
)
