# Sharing state

Learn techniques for sharing state throughout many parts of your application, and how to persist
data to user defaults, the file system, and other external mediums.

## Overview

Sharing state is the process of letting many features have access to the same data so that when any
feature makes a change to this data it is instantly visible to every other feature. Such sharing can
be really handy, but also does not play nicely with value types, which are copied rather than
shared. Because the Composable Architecture highly prefers modeling domains with value types rather
than reference types, sharing state can be tricky.

This is why the library comes with a few tools for sharing state with many parts of your
application. There are two main kinds of shared state in the library: explicitly passed state and
persisted state. And there are 3 persistence strategies shipped with the library: 
[in-memory](<doc:PersistenceKey/inMemory(_:)>),
[user defaults](<doc:PersistenceKey/appStorage(_:)-2gb5m>), and 
[file storage](<doc:PersistenceKey/fileStorage(_:)>). You can also implement your own persistence 
strategy if you want to use something other than user defaults or the file system, such as SQLite.

* ["Source of truth"](#Source-of-truth)
* [Explicit shared state](#Explicit-shared-state)
* [Persisted shared state](#Persisted-shared-state)
  * [In-memory](#In-memory)
  * [User defaults](#User-defaults)
  * [File storage](#File-storage)
  * [Custom persistence](#Custom-persistence)
* [Observing changes to shared state](#Observing-changes-to-shared-state)
* [Initialization rules](#Initialization-rules)
* [Deriving shared state](#Deriving-shared-state)
* [Testing](#Testing)
* [Type-safe keys](#Type-safe-keys)
* [Shared state in pre-observation apps](#Shared-state-in-pre-observation-apps)
* [Gotchas of @Shared](#Gotchas-of-Shared)

## "Source of truth"

First a quick discussion on defining exactly what "shared state" is. A common concept thrown around
in architectural discussions is "single source of truth." This is the idea that the complete state
of an application, even its navigation, can be driven off a single piece of data. It's a great idea,
in theory, but in practice it can be quite difficult to completely embrace.

First of all, a _single_ piece of data to drive _all_ of application state is just not feasible.
There is a lot of state in an application that is fine to be local to a view and does not need 
global representation. For example, the state of whether a button is being pressed is probably fine
to reside privately inside the button.

And second, applications typically do not have a _single_ source of truth. That is far too 
simplistic. If your application loads data from an API, or from disk, or from user defaults, then
the "truth" for that data does not lie in your application. It lies externally.

In reality, there are _two_ sources of "truth" in any application. There is the state the 
application needs to execute its logic and behavior. This is the kind of state that determines if a
button is enabled or disabled, drives navigation such as sheets and drill-downs, and handles
validation of forms. Such state only makes sense for the application.

Then there is a second source of "truth" in an application, which is the data that lies in some 
external system and needs to be loaded into the application. Such state is best modeled as a 
dependency or using the shared state tools discussed in this article.

## Explicit shared state

This is the simplest kind of shared state to get start with. It allows you to share state amongst
many features without any persistence. The data is only held in memory, and will be cleared out the
next time the application is run.

To share data in this style, use the [`@Shared`](<doc:Shared>) property wrapper with no arguments.
For example, suppose you have a feature that holds a count and you want to be able to hand a shared
reference to that count to other features. You can do so by holding onto a `@Shared` property in
the feature's state:

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

> Important: It is not possible to provide a default to a `@Shared` value. It must be passed to the
> feature's state from the outside. See <doc:SharingState#Initialization-rules> for more 
> information about how to initialize types that use `@Shared`.

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

When the parent features creates the child feature's state, it can pass a _reference_ to the shared
count rather than the actual count value by using the `$count` ``Shared/projectedValue``:

```swift
case .presentButtonTapped:
  state.child = ChildFeature.State(count: state.$count)
  // ...
```

Now any mutation the `ChildFeature` makes to its `count` will be instantly made to the 
`ParentFeature`'s count too.

## Persisted shared state

Explicitly shared state discussed above is a nice, lightweight way to share a piece of data with
many parts of your application. However, sometimes you want to share state with the entire 
application without having to pass it around explicitly. One can do this by passing a
``PersistenceKey`` to the `@Shared` property wrapper, and the library comes with three persistence
strategies, as well as the ability to create custom persistence strategies.

#### In-memory

This is the simplest persistence strategy in that it doesn't actually persist at all. It keeps
the data in memory and makes it available to every part of the application, but when the app is
relaunched the data will be reset back to its default.

It can be used by passing ``PersistenceKey/inMemory(_:)`` to the `@Shared` property wrapper. For
example, suppose you want to share an integer count value with the entire application so that any
feature can read from and write to the integer. This can be done like so:

```swift
@Reducer
struct ChildFeature {
  @ObservableState
  struct State {
    @Shared(.inMemory("count")) var count = 0
    // Other properties
  }
  // ...
}
```

> Note: When using a persistence strategy with `@Shared` you must provide a default value, which is
> used for the first access of the shared state.

Now any part of the application can read from and write to this state, and features will never
get out of sync.

#### User defaults

If you would like to persist your shared value across application launches, then you can use the
``PersistenceKey/appStorage(_:)-9zd2f`` strategy with `@Shared` in order to automatically persist
any changes to the value to user defaults. It works similarly to in-memory sharing discussed above.
It requires a key to store the value in user defaults, as well as a default value that will be
used when there is no value in the user defaults:

```swift
@Shared(.appStorage("count")) var count = 0
```

That small change will guarantee that all changes to `count` are persisted and will be 
automatically loaded the next time the application launches.

This form of persistence only works for simple data types because that is what works best with
`UserDefaults`. This includes strings, booleans, integers, doubles, URLs, data, and more. If you
need to store more complex data, such as custom data types serialized to JSON, then you will want
to use the [`.fileStorage`](<doc:SharingState#File-storage>) strategy or a 
[custom persistence](<doc:SharingState#Custom-persistence>) strategy.

#### File storage

If you would like to persist your shared value across application launches, and your value is
complex (such as a custom data type), then you can use the ``PersistenceKey/fileStorage(_:)``
strategy with `@Shared`. It automatically persists any changes to the file system.

It works similarly to the in-memory sharing discussed above, but it requires a URL to store the data
on disk, as well as a default value that will be used when there is no data in the file system:

```swift
@Shared(.fileStorage(URL(/* ... */)) var users: [User] = []
```

This strategy works by serializing your value to JSON to save to disk, and then deserializing JSON
when loading from disk. For this reason the value held in `@Shared(.fileStorage(…))` must conform to
`Codable`.

#### Custom persistence

It is possible to define all new persistence strategies for the times that user defaults or JSON
files are not sufficient. To do so, define a type that conforms to the ``PersistenceKey`` protocol:

```swift
public final class CustomPersistenceKey: PersistenceKey {
  // ...
}
```

And then define a static function on the ``PersistenceKey`` protocol for creating your new
persistence strategy:

```swift
extension PersistenceReaderKey {
  public static func custom<Value>(/*...*/) -> Self
  where Self == CustomPersistence<Value> {
    CustomPersistence(/* ... */)
  }
}
```

With those steps done you can make use of the strategy in the same way one does for 
``PersistenceKey/appStorage(_:)-9zd2f`` and ``PersistenceKey/fileStorage(_:)``:

```swift
@Shared(.custom(/* ... */)) var myValue: Value
```

## Observing changes to shared state

The ``Shared`` property wrapper exposes a ``Shared/publisher`` property so that you can observe
changes to the reference from any part of your application. For example, if some feature in your
app wants to listen for changes to some shared `count` value, then it can introduce an `onAppear`
action that kicks off a long-living effect that subscribes to changes of `count`:

```swift
case .onAppear:
  return .publisher {
    state.$count.publisher
      .map(Action.countUpdated)
  }

case .countUpdated(let count):
  print("Count updated to \(count)")
  return .none
```

Note that you will have to be careful for features that both hold onto shared state and subscribe
to changes to that state. It is possible to introduce an infinite loop if you do something like 
this:

```swift
case .onAppear:
  return .publisher {
    state.$count.publisher
      .map(Action.countUpdated)
  }

case .countUpdated(let count):
  state.count = count + 1
  return .none
```

If `count` changes, then `$count.publisher` emits, causing the `countUpdated` action to be sent, 
causing the shared `count` to be mutated, causing `$count.publisher` to emit, and so on. 

## Initialization rules

Because the state sharing tools use property wrappers there are special rules that must be followed
when writing custom initializers for your types. These rules apply to _any_ kind of property 
wrapper, including those that ship with vanilla SwiftUI (e.g. `@State`, `@StateObject`, etc.),
but the rules can be quite confusing and so below we describe the various ways to initialize
shared state.

It is common to need to provide a custom initializer to your feature's 
``Reducer/State`` type, especially when modularizing. When using
[`@Shared`](<doc:Shared>) in your `State` that can become complicated.
Depending on your exact situation you can do one of the following:

* You are using non-persisted shared state (i.e. no argument is passed to `@Shared`), and the 
"source of truth" of the state lives with the parent feature. Then the initializer should take a 
`Shared` value and you can assign through the underscored property:

  ```swift
  public struct State {
    @Shared public var count: Int
    // other fields

    public init(count: Shared<Int>, /* other fields */) {
      self._count = count
      // other assignments
    }
  }
  ```

* You are using non-persisted shared state (i.e. no argument is passed to `@Shared`), and the 
"source of truth" of the state lives within the feature you are initializing. Then the initializer
should take a plain, non-`Shared` value and you construct the `Shared` value in the initializer:

  ```swift
  public struct State {
    @Shared public var count: Int
    // other fields

    public init(count: Int, /* other fields */) {
      self._count = Shared(count)
      // other assignments
    }
  }
  ```

* You are using a persistence strategy with shared state (_e.g._ 
``PersistenceKey/appStorage(_:)-6nc2t``, ``PersistenceKey/fileStorage(_:)``, etc.), then the
initializer should take a plain, non-`Shared` value and you construct the `Shared` value in the
initializer using ``Shared/init(wrappedValue:_:fileID:line:)`` which takes a
``PersistenceKey`` as the second argument:

  ```swift
  public struct State {
    @Shared public var count: Int
    // other fields

    public init(count: Int, /* other fields */) {
      self._count = Shared(wrappedValue: count, .appStorage("count"))
      // other assignments
    }
  }
  ```

  The declaration of `count` can use `@Shared` without an argument because the persistence
  strategy is specified in the initializer.

  > Important: The value passed to this initializer is only used if the external storage does not
  > already have a value. If a value exists in the storage then it is not used. In fact, the
  > `wrappedValue` argument of ``Shared/init(wrappedValue:_:fileID:line:)`` is an 
  > `@autoclosure` so that it is not even evaluated if not used. For that reason you
  > may prefer to make the argument to the initializer an `@autoclosure` so that it too is evaluated
  > only if actually used:
  > 
  > ```swift
  > public struct State {
  >   @Shared public var count: Int
  >   // other fields
  > 
  >   public init(count: @autoclosure () -> Int, /* other fields */) {
  >     self._count = Shared(wrappedValue: count(), .appStorage("count"))
  >     // other assignments
  >   }
  > }
  > ```

## Deriving shared state

It is possible to derive shared state for sub-parts of an existing piece of shared state. For 
example, suppose you have a multi-step signup flow that uses `Shared<SignUpData>` in order to share
data between each screen. However, some screens may not need all of `SignUpData`, but instesad just
a small part. The phone number confirmation screen may only need access to `signUpData.phoneNumber`,
and so that feature can hold onto just `Shared<String>` to express this fact:

```swift
@Reducer 
struct PhoneNumberFeature { 
  struct State {
    @Shared var phoneNumber: String
  }
  // ...
}
```

Then, when the parent feature constructs the `PhoneNumberFeature` it can derive a small piece of
shared state from `Shared<SignUpData>` to pass along:

```swift
case .nextButtonTapped:
  state.path.append(
    PhoneNumberFeature.State(phoneNumber: state.$signUpData.phoneNumber)
  )
```

Here we are using the ``Shared/projectedValue`` value using `$` syntax, `$signUpData`, and then
further dot-chaining onto that projection to derive a `Shared<String>`. This can be a powerful way
for features to hold onto only the bare minimum of shared state it needs to do its job.

It can be instructive to think of `@Shared` as the Composable Architecture analogue of `@Bindable`
in vanilla SwiftUI. You use it to express that the actual "source of truth" of the value lies 
elsewhere, but you want to be able to read its most current value and write to it.

This also works for persistence strategies. If a parent feature holds onto a `@Shared` piece of 
state with a persistence strategy:

```swift
@Reducer
struct ParentFeature {
  struct State {
    @Shared(.fileStorage(.currentUser)) var currentUser
  }
  // ...
}
```

…and a child feature wants access to just a shared _piece_ of `currentUser`, such as their name, 
then they can do so by holding onto a simple, unadorned `@Shared`:

```swift
@Reducer
struct ChildFeature {
  struct State {
    @Shared var currentUserName: String
  }
  // ...
}
```

And then the parent can pass along `$currentUser.name` to the child feature when constructing its
state:

```swift
case .editNameButtonTapped:
  state.destination = .editName(
    EditNameFeature(name: state.$currentUser.name)
  )
```

Any changes the child feature makes to its shared `name` will be automatically made to the 
parent's shared `currentUser`, and further those changes will be automatically persisted thanks
to the `.fileStorage` persistence strategy used. This means the child feature gets to describe that
it needs access to shared state without describing the persistence strategy, and the parent can
be responsible for persisting and deriving shared state to pass to the child.

There is another tool for deriving shared state, and it is the computed property ``Shared/elements``
that is defined on shared collections. It derives a collection of shared elements so that you can
get access to a shared reference of just one particular element in a collection. 

This can be useful when used in conjunction with `ForEach` in order to derive a shared reference for 
each element of a collection:

```swift
struct State {
  @Shared(.fileStorage(.todos)) var todos: IdentifiedArrayOf<Todo> = []
  // ...
}

// ...

ForEach(store.$todos.elements) { $todo in
  NavigationLink(
    // $todo: Shared<Todo>
    //  todo: Todo
    state: Path.State.todo(TodoFeature.State(todo: $todo))
  ) {
    Text(todo.title)
  }
}
```

## Testing

Shared state behaves quite a bit different from the regular state held in Composable Architecture
features. It is capable of being changed by any part of the application, not just when an action is
sent to the store, and it has reference semantics rather than value semantics. Typically references
cause serious problems with testing, especially exhaustive testing that the library prefers (see
<doc:Testing>), because references cannot be copied and so one cannot inspect the changes before and
after an action is sent.

For this reason, the ``Shared`` macro does extra work during testing to preserve a previous snapshot 
of the state so that one can still exhaustively assert on shared state, even though it is a 
reference.

For the most part, shared state can be tested just like any regular state held in your features. For
example, consider the following simple counter feature that uses in-memory shared state for the
count:

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

This test passes because we have described how the state changes. But even better, if we mutate the
`count` incorrectly:


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

This works even though the `@Shared` count is a reference type. The ``TestStore`` and ``Shared``
type work in unison to snapshot the state before and after the action is sent, allowing us to still
assert in an exhaustive manner.

However, exhaustively testing shared state is more complicated than testing non-shared state in
features. Shared state can be captured in effects and mutated directly, without ever sending an
action into system. This is in stark contrast to regular state, which can only ever be mutated when
sending an action.

For example, it is possible to alter the `incrementButtonTapped` action so that it captures the 
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

It is also possible to test when using one of the persistence strategies provided by the library, 
which are ``PersistenceKey/appStorage(_:)-9zd2f`` and ``PersistenceKey/fileStorage(_:)``. Typically
persistence is difficult to test because the persisted data bleeds over from test to test, making it
difficult to exhaustively prove how each test behaves in isolation.

But the `.appStorage` and `.fileStorage` strategies do extra work to make sure that happens. By
default the `.appStorage` strategy uses a non-persisting user defaults so that changes are not
actually persisted across test runs. And the `.fileStorage` strategy uses a mock file system so that
changes to state are not actually persisted to the file system.

This means that if we altered the `SimpleFeature` of the <doc:SharingState#Testing> section above to
use app storage:

```swift
struct State: Equatable {
  @Shared(.appStorage("count")) var count: Int
}
````

…then the test for this feature can be written in the same way as before and will still pass.

#### Testing when using custom persistence strategies

When creating your own custom persistence strategies you must careful to do so in a style that
is amenable to testing. For example, the ``PersistenceKey/appStorage(_:)-9zd2f`` persistence
strategy that comes with the library injects a ``Dependencies/DependencyValues/defaultAppStorage``
dependency so that one can inject a custom `UserDefaults` in order to execute in a controlled
environment. By default ``Dependencies/DependencyValues/defaultAppStorage`` uses a non-persisting
user defaults, but you can also customize it to use any kind of defaults.

Similarly the ``PersistenceKey/fileStorage(_:)`` persistence strategy uses an internal dependency
for changing how files are written to the disk and loaded from disk. In tests the dependency will
forego any interaction with the file system and instead write data to a `[URL: Data]` dictionary,
and load data from that dictionary. That emulates how the file system works, but without persisting
any data to the global file system, which can bleed over into other tests.

## Type-safe keys

Due to the nature of persisting data to external systems, you lose some type safety when shuffling
data from your app to the persistence storage and back. For example, if you are using the
``PersistenceKey/fileStorage(_:)`` strategy to save an array of users to disk you might do so like
this:

```swift
extension URL {
  static let users = URL(/* ... */))
}

@Shared(.fileStorage(.users)) var users: [User] = []
```

And say you have used this file storage users in multiple places throughout your application.

But then, someday in the future you may decide to refactor this data to be an identified array
instead of a plain array:

```swift
// Somewhere else in the application
@Shared(.fileStorage(.users)) var users: IdentifiedArrayOf<User> = []
```

But if you forget to convert _all_ shared user arrays to the new identified array your application
will still compile, but it will be broken. The two types of storage will not share state.

To add some type-safety and reusability to this process you can extend the ``FileStorageKey`` type
to add a static variable for describing the details of your persistence:

```swift
extension PersistenceReaderKey where Self == FileStorageKey<IdentifiedArrayOf<User>> {
  static let users: Self {
    fileStorage(URL(/* ... */))
  }
}
```

Then when using [`@Shared`](<doc:Shared>) you can specify this key directly without `.fileStorage`:

```swift
@Shared(.users) var users: IdentifiedArrayOf<User> = []
```

And now that the type is baked into the key you can drop any type annotations from the field:

```swift
@Shared(.users) var users = []
```

And if you ever use the wrong type you will get an immediate compiler error:

```swift
@Shared(.users) var users = [User]()
```

> 🛑 Error:  Cannot convert value of type '[User]' to expected argument type 'IdentifiedArrayOf<User>'

This technique works for all types of persistence strategies. For example, a type-safe `.inMemory`
key can be constructed like so:

```swift
extension PersistenceReaderKey where Self == InMemoryKey<IdentifiedArrayOf<User>> {
  static var users: Self {
    inMemory("users")
  }
}
```

And a type-safe `.appStorage` key can be constructed like so:

```swift
extension PersistenceReaderKey where Self == AppStorageKey<Int> {
  static var count: Self {
    appStorage("count")
  }
}
```

And this technique also works on [custom persistence](<doc:SharingState#Custom-persistence>)
strategies.

## Shared state in pre-observation apps

It is possible to use [`@Shared`](<doc:Shared>) in features that have not yet been updated with
the observation tools released in 1.7, such as the ``ObservableState()`` macro. In the reducer
you can use `@Shared` regardless of your use of the observation tools. 

However, if you are deploying to iOS 16 or earlier, then you must use `WithPerceptionTracking`
in your views if you are accessing shared state. For example, the following view:

```swift
struct FeatureView: View {
  let store: StoreOf<Feature>

  var body: some View {
    Form {
      Text(store.sharedCount.description)
    }
  }
}
```

…will not update properly when `sharedCount` changes. This view will even generate a runtime warning
letting you know something is wrong:

> 🟣 Runtime Warning: Perceptible state was accessed but is not being tracked. Track changes to
> state by wrapping your view in a 'WithPerceptionTracking' view.

The fix is to wrap the body of the view in `WithPerceptionTracking`:

```swift
struct FeatureView: View {
  let store: StoreOf<Feature>

  var body: some View {
    WithPerceptionTracking {
      Form {
        Text(store.sharedCount.description)
      }
    }
  }
}
```

## Gotchas of @Shared

There are a few gotchas to be aware of when using shared state in the Composable Architecture.

#### Previews

When a preview is run in an app target, the entry point is also executed. This means if your entry
point looks something like this:

```swift
@main
struct MainApp: App {
  let store = Store(…)

  var body: some Scene {
    WindowGroup {
      AppView(store: store)
    }
  }
}
```

…then a store will be created each time you run your preview. This can be problematic with `@Shared`
and persistence strategies because the first access of a `@Shared` property will use the default
value provided, and that will make later `@Shared` access use the same default. That will mean
you cannot override shared state in previews.

The fix is to delay creation of the store until the entry point's `body` is executed, _and_ to 
further not execute the `body` when running for previews. Further, it can be a good idea to also
not run the `body` when in tests because that can also interfere with tests (as documented in
<doc:Testing#Testing-gotchas>). Here is one way this can be accomplished:

```swift
import ComposableArchitecture
import SwiftUI

@main
struct MainApp: App {
  @MainActor
  static let store = Store(…)

  var body: some Scene {
    WindowGroup {
      if 
        _XCTIsTesting || 
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" 
      {
        // NB: Don't run application in tests/previews to avoid interference 
        //     between the app and the test/preview.
        EmptyView()
      } else {
        AppView(store: Self.store)
      }
    }
  }
}
```

## Topics

### Essentials

- ``Shared``

### Persistence strategies

- ``AppStorageKey``
- ``FileStorageKey``
- ``InMemoryKey``

### Custom persistence

- ``PersistenceKey``
