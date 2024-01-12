load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Clocks",
    srcs = glob(
        ["Sources/Clocks/**/*.swift"],
    ),
    deps = [
        "@swift_concurrency_extras//:ConcurrencyExtras",
        "@xctest_dynamic_overlay//:XCTestDynamicOverlay",
    ],
    visibility = ["//visibility:public"],
)
