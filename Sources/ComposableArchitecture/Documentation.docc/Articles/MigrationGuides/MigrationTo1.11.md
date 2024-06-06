# Migrating to 1.11

Update your code to use the new ``Shared/withLock(_:)`` method for mutating shared state from
asynchronous contexts, rather than mutating the underlying wrapped value directly.

## Overview

The Composable Architecture is under constant development, and we are always looking for ways to
simplify the library, and make it more powerful. This version of the library introduced 2 new
APIs and deprecated 1 API.

> Important: Before following this migration guide be sure you have fully migrated to the newest
> tools of version 1.10. See <doc:MigrationGuides> for more information.

## Mutating shared state concurrently

Version 1.10 of the Composable Architecture introduced a powerful tool for 
[sharing state](<doc:SharingState>) amongst your features. And you can mutate a piece of shared
state directly, as if it were just a normal property on a value type:

```swift
case .incrementButtonTapped:
  state.count += 1
  return .none
```

And if you only ever mutate shared state from a reducer, then this is completely fine to do.
However, because shared values are secretly references (that is how data is shared), it is possible
to mutate shared values from effects, which means concurrently. And prior to 1.11, it was possible
to do this directly:

```swift
case .delayedIncrementButtonTapped:
  return .run { _ in
    @Shared(.count) var count
    count += 1
  }

Now, `Shared` is `Sendable`, and is technically thread-safe in that it will not crash when writing
to it from two different threads. However, allowing direct mutation does make the value susceptible
to race conditions. If you were to perform `count += 1` from 1,000 threads, it is possible for
the final value to not be 1,000.

We wanted the [`@Shared`](<doc:Shared>) type to be as ergonomic as possible, and that is why we make
it directly mutable, but we should not be allowing these mutations to happen from asynchronous
contexts. And so now the ``Shared/wrappedValue`` setter has been marked unavailable from
asynchronous contexts, with a helpful message of how to fix:

```swift
case .delayedIncrementButtonTapped:
  return .run { _ in
    @Shared(.count) var count
    count += 1  // ⚠️ Use '$shared.withLock' instead of mutating directly.
  }
```

To fix this deprecation you can use the new ``Shared/withLock(_:)`` method on the projected value of
`@Shared`:

```swift
case .delayedIncrementButtonTapped:
  return .run { _ in
    @Shared(.count) var count
    $count.withLock { $0 += 1 }
  }
```

This locks the entire unit of work of reading the current count, incrementing it, and storing it
back in the reference.

Technically it is still possible to write code that has race conditions, such as this silly example:

```swift
let currentCount = count
$count.withLock { $0 = currentCount + 1 }
```

But there is no way to 100% prevent race conditions in code. Even actors are susceptible to problems
due to re-entrancy. To avoid problems like the above we recommend wrapping as many mutations of the
shared state as possible in a single ``Shared/withLock(_:)``. That will make sure that the full unit
of work is guarded by a lock.

## Supplying mock read-only state to previews

A new ``SharedReader/constant(_:)`` helper on ``SharedReader`` has been introduced to simplify
supplying mock data to Xcode previews. It works like SwiftUI's `Binding.constant`, but for shared
references:

```swift
#Preview {
  FeatureView(
    store: Store(
      initialState: Feature.State(count: .constant(42))
    ) {
      Feature()
    }
  )
)
```
