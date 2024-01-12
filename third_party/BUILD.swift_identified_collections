load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "IdentifiedCollections",
    srcs = glob(
        ["Sources/IdentifiedCollections/**/*.swift"],
    ),
    deps = [
        "@swift_collections//:OrderedCollections",
    ],
    visibility = ["//visibility:public"],
)
