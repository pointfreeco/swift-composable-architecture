load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library", "swift_compiler_plugin")

swift_library(
    name = "Dependencies",
    srcs = glob(
        ["Sources/Dependencies/**/*.swift"],
    ),
    deps = [
        "@swift_clocks//:Clocks",
        "@combine_schedulers//:CombineSchedulers",
        "@swift_concurrency_extras//:ConcurrencyExtras",
        "@xctest_dynamic_overlay//:XCTestDynamicOverlay",
    ],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "DependenciesMacros",
    srcs = glob(
        ["Sources/DependenciesMacros/**/*.swift"],
    ),
    deps = [
        "@xctest_dynamic_overlay//:XCTestDynamicOverlay",
    ],
    plugins = [
        ":DependenciesMacrosPlugin",
    ],
    visibility = ["//visibility:public"],
)

swift_compiler_plugin(
    name = "DependenciesMacrosPlugin",
    srcs = glob(["Sources/DependenciesMacrosPlugin/**/*.swift"]),
    deps = [
        "@swift_syntax//:SwiftSyntaxMacros",
        "@swift_syntax//:SwiftCompilerPlugin",
    ]
)