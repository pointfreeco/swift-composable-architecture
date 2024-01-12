load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Given that this repo only uses `OrderedCollections`,
# we'll be soliciting only this library and its dependencies.
# Reference: https://github.com/apple/swift-collections/blob/main/Package.swift

swift_library(
    name = "OrderedCollections",
    srcs = glob(
        ["Sources/OrderedCollections/**/*.swift"],
    ),
    visibility = ["//visibility:public"],
)