# Migrating to 1.17

The `@Shared` property wrapper and related tools have been extracted to their own 
library so that they can be used in non-Composable Architecture applications. This a 
backwards compatible change, but some new deprecations have been introduced.

## Overview

The [Sharing][sharing-gh] package is a general purpose, state-sharing and persistence toolkit that
works on all platforms supported by Swift, including iOS/macOS, Linux, Windows, Wasm, and more.
We released two versions of this package simultaneously: a [0.1][0.1-release] version that is a
backwards-compatible version of the tools that shipped with the Composable Architecture <1.16, as
well as a [1.0][1.0-release] version with some non-backwards compatible changes.

If you wish to remain on the backwards-compatible version of Sharing for the time being, then you
can add an explicit dependency on the library to pin to any version less than 1.0:

```swift
.package(url: "https://github.com/pointfreeco/swift-sharing", from: "0.1.0"),
```

If you are ready to upgrade to 1.0, then you can follow the 
[1.0 migration guide][1.0-migration] from that package.

[sharing-gh]: https://github.com/pointfreeco/swift-sharing
[1.0-migration]: https://swiftpackageindex.com/pointfreeco/swift-sharing/main/documentation/sharing/migratingto1.0
[0.1-release]: https://github.com/pointfreeco/swift-sharing/releases/0.1.0
[1.0-release]: https://github.com/pointfreeco/swift-sharing/releases/1.0.0
