# Adopting Swift concurrency

Learn how to write safe, concurrent effects using Swift's structured concurrency.

As of version 5.6, Swift can provide many warnings for situations in which you might be using types
and functions that are not thread-safe in concurrent contexts. Many of these warnings can be ignored
for the time being, but in Swift 6 most (if not all) of these warnings will become errors, and so
you will need to know how to prove to the compiler that your types are safe to use concurrently.

There are 3 primary ways to create an ``Effect`` in the library:

  * ``Effect/task(priority:operation:catch:file:fileID:line:)``
  * ``Effect/run(priority:operation:catch:file:fileID:line:)``
  * ``Effect/fireAndForget(priority:_:)``

Each of these constructors takes a `@Sendable`, asynchronous closure, which restricts the types of
closures you can use for your effects. In particular, the closure can only capture `Sendable`
variables that are bound with `let`. Mutable variables and non-`Sendable` types are simply not
allowed to be passed to `@Sendable` closures.

There are two primary ways you will run into this restriction when building a feature in the
Composable Architecture: accessing state from within an effect, and accessing a dependency from
within an effect.

### Accessing state in an effect

Reducers are executed with a mutable, `inout` state variable, and such variables cannot be accessed
from within `@Sendable` closures:

```swift
struct Feature: ReducerProtocol {
  struct State { … }
  enum Action { … }

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    switch action {
    case .buttonTapped:
      return .task {
        try await Task.sleep(nanoseconds: NSEC_PER_SEC)
        return .delayed(state.count) 
        // 🛑 Mutable capture of 'inout' parameter 'state' is 
        //    not allowed in concurrently-executing code
      }

      …
    }
  }
}
```

To work around this you must explicitly capture the state as an immutable value for the scope of the
closure:

```swift
return .task { [state] in 
  try await Task.sleep(nanoseconds: NSEC_PER_SEC)
  return .delayed(state.count) // ✅
}
```

You can also capture just the minimal parts of the state you need for the effect by binding a new
variable name for the capture:

```swift
return .task { [count = state.count] in 
  try await Task.sleep(nanoseconds: NSEC_PER_SEC)
  return .delayed(count) // ✅
}
```

### Accessing dependencies in an effect

In the Composable Architecture, one provides dependencies to a reducer so that it can interact with
the outside world in a determinstic and controlled manner. Dependencies are typically accessed 
inside the effect, which means it must be `Sendable`, otherwise we will get the following warning 
(and error in Swift 6):

```swift
struct Feature: ReducerProtocol {
  struct State { … } 
  enum Action { … }
  @Dependency(\.factClient) var factClient

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    switch action {
    case .numberFactButtonTapped:
      return .task { [count = state.count] in
        await .numberFactResponse(
          TaskResult { try await self.factClient.fetch(count) }
        )
        // ⚠️ Capture of 'self' with non-sendable type 'Feature' 
        //    in a `@Sendable` closure
      }
    }
  }
}
```

To fix this we need to make each dependency client `Sendable`. This usually just means making sure 
that the interface type only holds onto `Sendable` data, and in particular, any closure-based 
endpoints should be annotated as `@Sendable`:

```swift
struct FactClient {
  var fetch: @Sendable (Int) async throws -> String
}
```

This will restrict the kinds of closures that can be used when construct `FactClient` values, thus 
making the entire `FactClient` sendable itself.
