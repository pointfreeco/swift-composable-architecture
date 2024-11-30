# Migrating to 1.12

Take advantage of custom decoding and encoding logic for the shared file storage persistence
strategy, as well as beta support for Swift's native Testing framework.

## Overview

The Composable Architecture is under constant development, and we are always looking for ways to
simplify the library, and make it more powerful. This version of the library introduced 1 new
API, as well as beta support for Swift Testing.

> Important: Before following this migration guide be sure you have fully migrated to the newest
> tools of version 1.11. See <doc:MigrationGuides> for more information.

## Custom file storage coding

Version 1.10 of the Composable Architecture introduced a powerful tool for 
[sharing state](<doc:SharingState>) amongst your features, and included several built-in persistence
strategies, including file storage. This strategy, however, was not very flexible, and only
supported the default JSON encoding and decoding offered by Swift.

In this version, you can now define custom encoding and decoding logic using
`fileStorage(_:decode:encode:)`.

## Swift Testing

Xcode 16 and Swift 6 come with a powerful new native testing framework. Existing test targets using
XCTest can even incrementally adopt the framework and define new tests with Testing. Existing XCTest
test _helpers_, however, are not compatible with the new framework, and so test tools like the
Composable Architecture's `TestStore` did not work with it out of the box.

That changes with this version, which seamlessly supports XCTest _and_ Swift's Testing framework.
You can now create a test store in a `@Test` and failures will be reported accordingly.
