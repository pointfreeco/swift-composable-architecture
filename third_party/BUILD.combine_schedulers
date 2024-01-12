load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CombineSchedulers",
    srcs = glob(
        ["Sources/CombineSchedulers/**/*.swift"],
    ),
    deps = [
        "@swift_concurrency_extras//:ConcurrencyExtras",
        "@xctest_dynamic_overlay//:XCTestDynamicOverlay",
    ],
    visibility = ["//visibility:public"],
)
