load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CustomDump",
    srcs = glob(
        ["Sources/CustomDump/**/*.swift"],
    ),
    deps = [
        "@xctest_dynamic_overlay//:XCTestDynamicOverlay",
    ],
    visibility = ["//visibility:public"],
)
