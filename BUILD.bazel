load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library", "swift_test", "swift_compiler_plugin")

swift_library(
    name = "ComposableArchitecture",
    srcs = glob(
        ["Sources/ComposableArchitecture/**/*.swift"],
        exclude = [
            "Sources/ComposableArchitecture/Documentation.docc/**",
        ],
    ),
    deps = [
        "@swift_case_paths//:CasePaths",
        "@combine_schedulers//:CombineSchedulers",
        "@swift_concurrency_extras//:ConcurrencyExtras",
        "@swift_custom_dump//:CustomDump",
        "@swift_dependencies//:Dependencies",
        "@swift_dependencies//:DependenciesMacros",
        "@swift_identified_collections//:IdentifiedCollections",
        "@swift_collections//:OrderedCollections",
        "@swiftui_navigation//:SwiftUINavigationCore",
        "@xctest_dynamic_overlay//:XCTestDynamicOverlay",
    ],
    plugins = [
        ":ComposableArchitectureMacros",
    ],
    visibility = ["//visibility:public"],
)

swift_compiler_plugin(
    name = "ComposableArchitectureMacros",
    srcs = glob(["Sources/ComposableArchitectureMacros/**/*.swift"]),
    deps = [
        "@swift_syntax//:SwiftSyntaxMacros",
        "@swift_syntax//:SwiftCompilerPlugin",
    ],
    visibility = ["//visibility:public"],
)

swift_test(
    name = "ComposableArchitectureTests",
    srcs = glob(["Tests/ComposableArchitectureTests/**/*.swift"]),
    deps = [
        ":ComposableArchitecture",
    ]
)
