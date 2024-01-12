load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library", "swift_compiler_plugin")

swift_library(
    name = "CasePaths",
    srcs = glob(
        ["Sources/CasePaths/**/*.swift"],
    ),
    deps = [
        "@xctest_dynamic_overlay//:XCTestDynamicOverlay",
    ],
    plugins = [
        ":CasePathsMacros",
    ],
    visibility = ["//visibility:public"],
)

swift_compiler_plugin(
    name = "CasePathsMacros",
    srcs = glob(["Sources/CasePathsMacros/**/*.swift"]),
    deps = [
        "@swift_syntax//:SwiftSyntaxMacros",
        "@swift_syntax//:SwiftCompilerPlugin",
    ],
    visibility = ["//visibility:public"],
)
