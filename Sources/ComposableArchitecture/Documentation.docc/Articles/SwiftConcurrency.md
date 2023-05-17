# Adopting Swift concurrency

Learn how to write safe, concurrent effects using Swift's structured concurrency.

As of version 5.6, Swift can provide many warnings for situations in which you might be using types
and functions that are not thread-safe in concurrent contexts. Many of these warnings can be ignored
for the time being, but in Swift 6 most (if not all) of these warnings will become errors, and so
you will need to know how to prove to the compiler that your types are safe to use concurrently.

There primary way to create an ``EffectTask`` in the library is via
``EffectPublisher/run(priority:operation:catch:fileID:line:)``. It takes a `@Sendable`,
asynchronous closure, which restricts the types of closures you can use for your effects. In
particular, the closure can only capture `Sendable` variables that are bound with `let`. Mutable
variables and non-`Sendable` types are simply not allowed to be passed to `@Sendable` closures.

There are two primary ways you will run into this restriction when building a feature in the
Composable Architecture: accessing state from within an effect, and accessing a dependency from
within an effect.

### Accessing state in an effect

Reducers are executed with a mutable, `inout` state variable, and such variables cannot be accessed
from within `@Sendable` closures:

```swift
struct Feature: ReducerProtocol {
  struct State { /* ... */ }
  enum Action { /* ... */ }

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .buttonTapped:
      return .run { send in
        try await Task.sleep(for: .seconds(1))
        await send(.delayed(state.count))
        // 🛑 Mutable capture of 'inout' parameter 'state' is
        //    not allowed in concurrently-executing code
      }

      // ...
    }
  }
}
```

To work around this you must explicitly capture the state as an immutable value for the scope of the
closure:

```swift
return .run { [state] send in
  try await Task.sleep(for: .seconds(1))
  await send(.delayed(state.count))  // ✅
}
```

You can also capture just the minimal parts of the state you need for the effect by binding a new
variable name for the capture:

```swift
return .run { [count = state.count] send in
  try await Task.sleep(for: .seconds(1))
  return .delayed(count)  // ✅
}
```

### Accessing dependencies in an effect

In the Composable Architecture, one provides dependencies to a reducer so that it can interact with
the outside world in a deterministic and controlled manner. Those dependencies can be used from
asynchronous and concurrent contexts, and so must be `Sendable`.

If your dependency is not sendable, you will be notified at the time of registering it with the
library. In particular, when extending `DependencyValues` to provide the computed property:

```swift
extension DependencyValues {
  var factClient: FactClient {
    get { self[FactClient.self] }
    set { self[FactClient.self] = newValue }
  }
}
```

If `FactClient` is not `Sendable`, for whatever reason, you will get a warning in the `get`
and `set` lines:

```
⚠️ Type 'FactClient' does not conform to the 'Sendable' protocol
```

To fix this you need to make each dependency `Sendable`. This usually just means making sure 
that the interface type only holds onto `Sendable` data, and in particular, any closure-based 
endpoints should be annotated as `@Sendable`:

```swift
struct FactClient {
  var fetch: @Sendable (Int) async throws -> String
}
```

This will restrict the kinds of closures that can be used when constructing `FactClient` values, thus 
making the entire `FactClient` sendable itself.
