# Migrating to 1.17.1

The Sharing library has graduated, with backwards-incompatible changes, to 2.0, and the Composable
Architecture has been updated to extend support to this new version.

## Overview

The [Sharing][sharing-gh] package is a general purpose, state-sharing and persistence toolkit that
works on all platforms supported by Swift, including iOS/macOS, Linux, Windows, Wasm, and more.

A [2.0][2.0-release] has introduced new features and functionality, and the Composable Architecture
1.17.1 includes support for this release.

While many of Sharing 2.0's APIs are backwards-compatible with 1.0, if you have defined any of your
own custom persistence strategies via the `SharedKey` or `SharedReaderKey` protocols, you will need
to migrate them in order to support the brand new error handling and async functionality.

If you are not ready to migrate, then you can add an explicit dependency on the library to pin to
any version less than 2.0:

```swift
.package(url: "https://github.com/pointfreeco/swift-sharing", from: "0.1.0"),
```

If you are ready to upgrade to 2.0, then you can follow the [2.0 migration guide][2.0-migration]
from that package.

[sharing-gh]: https://github.com/pointfreeco/swift-sharing
[2.0-migration]: https://swiftpackageindex.com/pointfreeco/swift-sharing/main/documentation/sharing/migratingto2.0
[2.0-release]: https://github.com/pointfreeco/swift-sharing/releases/2.0.0
