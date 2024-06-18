# Migrating to 1.12

Update your code to `await` the ``Shared/withLock(_:)`` method for mutating shared state from
asynchronous contexts.

## Overview

The Composable Architecture is under constant development, and we are always looking for ways to
simplify the library, and make it more powerful. This version of the library fixed 1 bug that
may introduce a breaking change to your app. Find out how to fix the problem in this migration
guide.

> Important: Before following this migration guide be sure you have fully migrated to the newest
> tools of version 1.11. See <doc:MigrationGuides> for more information.

## `withLock` is now `@MainActor`

In [version 1.11](<doc:MigratingTo1.11>) of the library we deprecated mutating shared state from
asynchronous contexts, such as effects, and instead recommended using the new 
``Shared/withLock(_:)`` method. Doing so made it possible to lock all mutations to the shared state
and prevent race conditions (see the [migration guide](<doc:MigratingTo1.11>) for more info).

However, this did leave open the possibility for deadlocks if shared state was read from and written
to on different threads. To fix this we have now restricted ``Shared/withLock(_:)`` to the
`@MainActor`, and so you will now need to `await` its usage:

```diff
-sharedCount.withLock { $0 += 1 }
+ await sharedCount.withLock { $0 += 1 }
```
