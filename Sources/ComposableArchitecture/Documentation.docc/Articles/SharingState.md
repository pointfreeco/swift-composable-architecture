# Sharing state

Learn techniques for sharing state throughout many parts of your application.

## Overview

Sharing state is the process of letting many features have access to the same data so that when
any feature makes a change to the data it is instantly visible to every other feature. Such sharing
can be really handy, but also does not place nicely with value types, which are copied rather than
shared. And since the Composable Architecture highly prefers modeling domains with value types
rather than reference types, sharing state can be tricky.

This is why the library comes with a few tools for sharing state with many parts of your 
application. There are 3 main strategies shipped with the library: in-memory sharing, user defaults
persistence, and file storage persistence. You can also implement your own persistence strategy
if you want to use something besides user defaults or the file system, such as SQLite.

### "Source of truth"

First a quick discussion on defining exactly what "shared state" is.

<!--
todo: discuss "source of truth"?
-->

### In memory

This strategy allows you to share state amongst many features without any persistence. The data is
only held in memory, and will be cleared out next time the application is run.

To share data in this style, use the ``Shared`` property wrapper with no arguments. For example,
suppose you have a feature that holds a count and you want to be able to hand a shared reference
of that count to other features. You can do so by holding onto an `@Shared` property in the 
feature's state:

```swift
@Reducer
struct ParentFeature {
  @ObservableState
  struct State {
    @Shared var count: Int
    // Other properties
  }
  // ...
}
```

> Important: It is not possible to provide a default to an in-memory `@Shared` value. It must be passed
to this feature's state from the outside.

Then suppose that this feature can present a child feature that wants access to this shared `count`
value. It too would hold onto an `@Shared` property to a count:

```swift
@Reducer
struct ChildFeature {
  @ObservableState
  struct State {
    @Shared var count: Int
    // Other properties
  }
  // ...
}
```

When the parent features creates the child feature's state, it can pass a _reference_ to the
shared count rather than the actual count value by using the `$count` projected value:

```swift
case .presentButtonTapped:
  state.child = ChildFeature.State(count: state.$count)
  // ...
```

Now any mutation the `ChildFeature` makes to its `count` will be instantly made to the 
`ParentFeature`'s count too.

### User defaults

If you would like to persist your shared value across application launches, then you can use the
``SharedPersistence/appStorage(_:)-687rl`` strategy with `@Shared` in order to automatically
persist any changes to the value to user defaults. It works similarly to in-memory sharing 
discussed above, but it requires a key to store the value in user defaults, as well as a default
value that will be used when there is no value in the user defaults:

```swift
@Shared(.appStorage("count")) var count = 0
```

That small change will guarantee that all changes to `count` are persisted and will be 
automatically loaded next time the application launches.

This form of persistence only works for simple data types because that is what works best with
`UserDefaults`. This includes strings, booleans, integers, doubles, URLs, data and more. If you
need to store more complex data, such as custom data types serialized to JSON, then you will want
to use the <doc:SharingState#File-storage> strategy or a <doc:SharingState#Custom-persistence>
strategy.

### File storage

If you would like to persist your shared value across application launches, and your value is 
complex (such as a custom data type), then you can use the ``SharedPersistence/fileStorage(_:)``
strategy with `@Shared`. It automatically persists any changes to the value to the file system.

It works similarly to the in-memory sharing discussed above, but it requires a URL to store the
data on disk, as well as a default value that will be used when there is no data in the file 
system:

```swift
extension URL {
  static let users = URL.documentsDirectory.appending(path: "users.json")
}

@Shared(.fileStorage(.users)) var users: [User] = []
```

This strategy works by serializing your value to JSON to save to disk, and then deserializing JSON
when loading from disk. For this reason the value held in `@Shared(.fileStorage(…))` must conform
to `Codable`.

### Custom persistence

It is possible to define all new persistence strategies for the times that user defaults or JSON
files are not sufficient. To do so, define a type that conforms to the ``SharedPersistence``
protocol:

```swift
public final class CustomPersistence: SharedPersistence {
  // ...
}
```

And then define a static function on ``SharedPersistence`` for creating your new persistence
strategy:

```swift
extension SharedPersistence {
  public static func custom<Value>(/*...*/) -> Self
  where Self == CustomPersistence<Value> {
    CustomPersistence(/*...*/)
  }
}
```

With those steps done you can make use of the strategy in the same way one does for 
``SharedPersistence/appStorage(_:)-73sv4`` and ``SharedPersistence/fileStorage(_:)``:

```swift
@Shared(.custom(/*...*/)) var myValue: Value
```

### Testing

Share state behaves quite a bit different from the regular state held in Composable Architecture
features. It is capable of being changed by any part of the application, not just went an action
is sent to the store, and it has reference semantics rather than value semantics. Typically
references cause series problems with testing, especially exhaustive testing that the library
prefers (see <doc:Testing>), because references cannot be copied and so one cannot inspect the
changes before and after an action is sent.

For this reason, the ``Shared`` does extra working during testing to preserve a previous snapshot 
of the state so that one can still exhaustive assert on shared state, even though it is a reference.

For the most part, shared state can be tested just like any regular state held in your features.
For example, consider the following simple counter feature that uses in-memory shared state for
the count:

```swift
@Reducer 
struct Feature {
  struct State: Equatable {
    @Shared var count: Int
  }
  enum Action {
    case incrementButtonTapped
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .incrementButtonTapped:
        state.count += 1
        return .none
      }
    }
  }
}
```

This feature can be tested in exactly the same way as when you are using non-shared state:

```swift
func testIncrement() async {
  let store = TestStore(initialState: Feature.State(count: Shared(0))) {
    Feature()
  }

  await store.send(.incrementButtonTapped) {
    $0.count = 1
  }
}
```

This test passes because we have described how the state changes. But even better, if we mutate
the `count` incorrectly:


```swift
func testIncrement() async {
  let store = TestStore(initialState: Feature.State(count: Shared(0))) {
    Feature()
  }

  await store.send(.incrementButtonTapped) {
    $0.count = 2
  }
}
```

…we immediately get a test failure letting us know exactly what went wrong:

```
❌ State was not expected to change, but a change occurred: …

    − Feature.State(_count: 2)
    + Feature.State(_count: 1)

(Expected: −, Actual: +)
```

THis works even though the `@Shared` count is a reference type. The ``TestStore`` and ``Shared``
type work in unison to snapshot the state before and after the action is sent, allowing us to
still assert in an exhaustive manner.

However, exhaustively testing shared state is more complicated than testing non-shared state in
features. Shared state can be captured in effects and mutated directly, without ever sending an
action into system. This is in start contrast to regular state, which can only ever be mutated
when sending an action.

For example, it is possible to alter the `incrementButtonTapped` action so that it capures the 
shared state in an effect, and then increments from the effect:

```swift
case .incrementButtonTapped:
  return .run { [count = state.$count] _ in
    count.wrappedValue += 1
  }
```

The only reason this is possible is because `@Shared` state is reference-like, and hence can 
technically be mutated from anywhere.

However, how does this affect testing? Since the `count` is no longer incremented directly in
the reducer we can drop the trailing closure from the test store assertion:

```swift
func testIncrement() async {
  let store = TestStore(initialState: SimpleFeature.State(count: Shared(0))) {
    SimpleFeature()
  }
  await store.send(.incrementButtonTapped)
}
```

This is technically correct, but we aren't testing the behavior of the effect at all.

Luckily the ``TestStore`` has our back. If you run this test you will immediately get a failure
letting you know that the shared count was mutated but we did not assert on the changes:

```
❌ Tracked changes to 'Shared<Int>@MyAppTests/FeatureTests.swift:10' but failed to assert: …

  − 0
  + 1

(Before: −, After: +)

Call 'Shared<Int>.assert' to exhaustively test these changes, or call 'skipChanges' to ignore them.
```

In order to get this test passing we have to explicitly assert on the shared counter state at
the end of the test, which we can do using the ``Shared/assert(_:file:line:)`` method:

```swift
func testIncrement() async {
  let store = TestStore(initialState: SimpleFeature.State(count: Shared(0))) {
    SimpleFeature()
  }
  await store.send(.incrementButtonTapped)
  store.state.$count.assert {
    $0 = 1
  }
}
```

Now the test passes.

So, even though the `@Shared` type opens our application up to a little bit more uncertainty due
to its reference semantics, it is still possible to get exhaustive test coverage on its changes.

#### Testing when using persistence

<!--
todo: discuss testing user defaults and file storage
-->
