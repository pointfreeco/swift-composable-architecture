# Dependencies

Learn how to register dependencies with the library so that they can be immediately accessible from
any reducer.

## Overview

Dependencies in an application are the types and functions that need to interact with outside 
systems that you do not control. Classic examples of this are API clients that make network requests
to servers, but also seemingly innocuous things such as `UUID` and `Date` initializers, and even
clocks, can be thought of as dependencies.

By controlling the dependencies our features need to do their job we gain the ability to completely
alter the execution context a feature runs in. This means in tests and Xcode previews you can 
provide a mock version of an API client that immediately returns some stubbed data rather than 
making a live network request to a server.

* [The need for controlled dependencies](#The-need-for-controlled-dependencies)
* [Using library dependencies](#Using-library-dependencies)
* [Registering your own dependencies](#Registering-your-own-dependencies)
* [Live, preview and test dependencies](#Live-preview-and-test-dependencies)
* [Designing dependencies](#Designing-dependencies)
* [Overriding dependencies](#Overriding-dependencies)

## The need for controlled dependencies

Suppose that you are building a todo application with a `Todo` model that has a UUID identifier:

```swift
struct Todo: Equatable, Identifiable {
  let id: UUID
  var title = ""
  var isCompleted = false
}
```

And suppose you have a reducer that handles an action for when the "Add todo" button is tapped, 
which appends a new todo to the end of the array:

```swift
struct Todos: ReducerProtocol {
  struct State {
    var todos: IdentifiedArrayOf<Todo> = []
    // ...
  }
  enum Action {
    case addButtonTapped
    // ...
  }

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .addButtonTapped:
      state.todos.append(Todo(id: UUID())
      return .none

    // ...
    }
  }
}
```

> Tip: We are using `IdentifiedArray` from our 
[Identified Collections][swift-identified-collections] library because it provides a safe and
ergonomic API for accessing elements from a stable ID rather than positional indices.

In the reducer we are using the uncontrolled `UUID` initializer from Foundation. Every invocation
of the initializer produces a fully random UUID. That may seem like what we want, but unfortunately
it wreaks havoc on our ability to test.

If we tried writing a test for the add todo functionality we will quickly find that we can't
possibly predict what UUID will be produced for the new todo:

```swift
@MainActor
func testAddTodo() async {
  let store = TestStore(
    initialState: Todos.State(), 
    reducer: Todos()
  )

  await store.send(.addButtonTapped) {
    $0.todos = [
      Todo(id: ???)
    ]
  }
}
```

> Tip: Read the <doc:Testing> article to learn how to write tests for state mutations and effect 
> execution in your features.

There is no way to get this test to pass.

This is why controlling dependencies is important. It allows us to substitute a UUID generator that
is deterministic in tests, such as one that simply increments by 1 every time it is invoked.

The library comes with a controlled UUID generator and can be accessed by using the 
`@Dependency` property wrapper to add a dependency to the `Todos` reducer:

```swift
struct Todos: ReducerProtocol {
  @Dependency(\.uuid) var uuid
  // ...
}
```

Then when you need a new UUID you should reach for the dependency rather than reaching for the 
uncontrollable UUID initializer:

```swift
case .addButtonTapped:
  state.todos.append(Todo(id: self.uuid()) // ⬅️
  return .none
```

If you do this little bit of upfront work you instantly unlock the ability to test the feature by
providing a controlled, deterministic version of the UUID generator in tests. The library even comes
with such a version for the UUID generator, and it is called `incrementing`. You can override
the dependency directly on the ``TestStore`` so that your feature's reducer uses that version
instead of the live one:

```swift
@MainActor
func testAddTodo() async {
  let store = TestStore(
    initialState: Todos.State(), 
    reducer: Todos()
  )

  store.dependencies.uuid = .incrementing

  await store.send(.addButtonTapped) {
    $0.todos = [
      Todo(id: UUID(string: "00000000-0000-0000-0000-000000000000")!)
    ]
  }
}
```

This test will pass deterministically, 100% of the time, and this is why it is so important to 
control dependencies that interact with outside systems.

## Using library dependencies

The library comes with many common dependencies that can be used in a controllable manner, such as
date generators, clocks, random number generators, UUID generators, and more.

For example, suppose you have a feature that needs access to a date initializer, the continuous
clock for time-based asynchrony, and a UUID initializer. All 3 dependencies can be added to your 
feature's reducer:

```swift
struct Todos: ReducerProtocol {
  struct State {
    // ...
  }
  enum Action {
    // ...
  }
  @Dependency(\.date) var date
  @Dependency(\.continuousClock) var clock
  @Dependency(\.uuid) var uuid

  // ...
}
```

Then, all 3 dependencies can easily be overridden with deterministic versions when testing the 
feature:

```swift
@MainActor
func testTodos() async {
  let store = TestStore(
    initialState: Todos.State(),
    reducer: Todos()
  )

  store.dependencies.date = .constant(Date(timeIntervalSinceReferenceDate: 1234567890))
  store.dependencies.continuousClock = ImmediateClock()
  store.dependencies.uuid = .incrementing

  // ...
}
```

## Registering your own dependencies

Although the library comes with many controllable dependencies out of the box, there are still 
times when you want to register your own dependencies with the library so that you can use the
`@Dependency` property wrapper. Doing this is quite similar to  registering an
[environment value][environment-values-docs] in SwiftUI.

First you create a type that conforms to the `DependencyKey` protocol. The minimum implementation
you must provide is a `liveValue`, which is the value used when running the app in a simulator or
on device, and so it's appropriate for it to actually make network requests to an external server:

```swift
private enum APIClientKey: DependencyKey {
  static let liveValue = APIClient.live
}
```

> Tip: There are two other values you can provide for a dependency. If you implement `testValue`
it will be used when testing features in a ``TestStore``, and if you implement `previewValue` it 
will be used while running features in an Xcode preview. You don't need to worry about those
values when you are just getting started, and instead can 
[add them later](#Live-preview-and-test-dependencies).

Finally, an extension must be made to `DependencyValues` to expose a computed property for the
dependency:

```swift
extension DependencyValues {
  var apiClient: APIClient {
    get { self[APIClientKey.self] }
    set { self[APIClientKey.self] = newValue }
  }
}
```

With those few steps completed you can instantly access your API client dependency from any 
feature's reducer by using the `@Dependency` property wrapper:

```swift
struct Todos: ReducerProtocol {
  @Dependency(\.apiClient) var apiClient
  // ...
}
```

This will automatically use the live dependency in previews, simulators and devices, and in
tests you can override any endpoint of the dependency to return mock data:

```swift
@MainActor
func testFetchUser() async {
  let store = TestStore(
    initialState: Todos.State(),
    reducer: Todos()
  )

  store.dependencies.apiClient.fetchUser = { _ in User(id: 1, name: "Blob") }

  await store.send(.loadButtonTapped)
  await store.receive(.userResponse(.success(User(id: 1, name: "Blob")))) {
    $0.loadedUser = User(id: 1, name: "Blob")
  }
}
```

Often times it is not necessary to create a whole new type to conform to `DependencyKey`. If the
dependency you are registering is a type that you own, then you can conform it directly to the 
protocol:

```swift
extension APIClient: DependencyKey {
  static let liveValue = APIClient.live
}

extension DependencyValues {
  var apiClient: APIClient {
    get { self[APIClient.self] }
    set { self[APIClient.self] = newValue }
  }
}
```

That can save a little bit of boilerplate.

## Live, preview and test dependencies

In the previous section we showed that to conform to `DependencyKey` you must provide _at least_
a `liveValue`, which is the default version of the dependency that is used when running on a
device or simulator. The `DependencyKey` protocol inherits from a base protocol,
`TestDependencyKey`, which has 2 other requirements, `testValue` and `previewValue`. Both are
optional and delegate to `liveValue` if not implemented.

If you implement a static `testValue` property on your key, that value will be used when running 
your feature in a ``TestStore``. This is a great opportunity to supply a mocked version of the 
dependency that does not reach out to the real world. By doing this you can guarantee that your 
tests will never accidentally make a network request, or track analytics events that are not 
actually tied to user actions, and more.

Further, we highly recommend you consider making your `testValue` dependency into what we like to 
call an "unimplemented" dependency. This is a version of your dependency that performs an `XCTFail`
in each endpoint so that if it is ever invoked in tests it will cause a test failure. This allows
you to be more explicit about what dependencies are actually needed to test a particular user
flow in your feature.

For example, suppose you have an API client with endpoints for fetching a list of users or fetching
a particular user by id:

```swift
struct APIClient {
  var fetchUser: (User.ID) async throws -> User
  var fetchUsers: () async throws -> [User]
}
```

Then we can construct an "unimplemented" version of this dependency that invokes `XCTFail` when
any endpoint is invoked

```swift
extension APIClient {
  static let unimplemented = Self(
    fetchUser: { _ in XCTFail("APIClient.fetchUser unimplemented") }
    fetchUsers: { XCTFail("APIClient.fetchUsers unimplemented") }
  )
}
```

Unfortunately, `XCTFail` cannot be used in non-test targets, and so this instance cannot be defined
in the same file where your dependency is registered. To work around this you can use our
[XCTestDynamicOverlay][xctest-dynamic-overlay-gh] library that dynamically invokes `XCTFail` and
it is automatically accessible when using the Composable Architecture. It also comes with some
helpers to ease the construction of these unimplemented values, which we can use when defining the
`testValue` of your dependency:

```swift
import XCTestDynamicOverlay

extension APIClient {
  static let testValue = Self(
    fetchUser: unimplemented("APIClient.fetchUser")
    fetchUsers: unimplemented("APIClient.fetchUsers")
  )
}
```

The other requirement of `TestDependencyKey` is `previewValue`, and if this value is implemented
it will be used whenever your feature is run in an Xcode preview. Previews are similar to tests in
that you usually do not want to interact with the outside world, such as making network requests.
In fact, many of Apple's frameworks do not work in previews, such as Core Location, and so it will
be hard to interact with your feature in previews if it touches those frameworks.

However, previews are dissimilar to tests in that it's fine for dependencies to return some mock 
data. There's no need to deal with "unimplemented" clients for proving which dependencies are 
actually used.

For the `APIClient` example from above, we might define its `previewValue` like so:

```swift
extension APIClient: TestDependencyKey {
  static let previewValue = Self(
    fetchUsers: { 
      [
        User(id: 1, name: "Blob"),
        User(id: 1, name: "Blob Jr."),
        User(id: 1, name: "Blob Sr."),
      ]
    },
    fetchUser: { id in 
      User(id: id, name: "Blob, id: \(id)")
    }
  )
}
```

Then when running a feature that uses this dependency in an Xcode preview will immediately get
data provided to it, making it easier for you to iterate on your feature's logic and styling.

## Designing dependencies

Making it possible to control your dependencies is the most important step you can take towards
making your features isolatable and testable. The second most important step after that is to
design your dependencies in a way that maximizes their flexibility in tests and other situations.

The most popular way to design dependencies in Swift is to use protocols. For example, if your
feature needs to interact with an audio player, you might design a protocol with methods for
playing, stopping, and more:

```swift
protocol AudioPlayer {
  func loop(_ url: URL) async throws
  func play(_ url: URL) async throws 
  func setVolume(_ volume: Float) async
  func stop() async
}
```

Then you are free to make as many conformances of this protocol as you want, such as a 
`LiveAudioPlayer` that actually interacts with AVFoundation, or a `MockAudioPlayer` that doesn't
play any sounds, but does suspend in order to simulate that something is playing. You could even
have an `UnimplementedAudioPlayer` conformance that invokes `XCTFail` when any method is invoked.
And all of those conformances can be used to specify the live, preview and test values for the
dependency:

```swift
private enum AudioPlayerKey: DependencyKey {
  static let liveValue: any AudioPlayer = LiveAudioPlayer()
  static let previewValue: any AudioPlayer = MockAudioPlayer()
  static let testValue: any AudioPlayer = UnimplementedAudioPlayer()
}
```

This style of dependencies works just fine, and if it is what you are most comfortable with then
there is no need to change.

However, there is a small change one can make to this dependency to unlock even more power. Rather
than designing the audio player as a protocol, we can use a struct with closure properties to 
represent the interface:

```swift
struct AudioPlayerClient {
  var loop: (_ url: URL) async throws -> Void
  var play: (_ url: URL) async throws -> Void
  var setVolume: (_ volume: Float) async -> Void
  var stop: () async -> Void
}
```

Then, rather than defining types that conform to the protocol you construct values:

```swift
extension AudioPlayerClient {
  static let live = Self(…)
  static let mock = Self(…)
  static let unimplemented = Self(…)
}
```

And to register the dependency you can leverage the struct that defines the interface. There's no 
need to define a new type:

```swift
extension AudioPlayerClient: DependencyKey {
  static let liveValue = AudioPlayerClient.live
  static let previewValue = AudioPlayerClient.mock
  static let testValue = AudioPlayerClient.unimplemented
}
```

If you design your dependencies in this way you can pick which dependency endpoints you need in your
feature. For example, if you have a feature that needs an audio player to do its job, but it only
needs the `play` endpoint, and doesn't need to loop, set volume or stop audio, then you can specify
a dependency on just that one function:

```swift
struct Feature: ReducerProtocol {
  @Dependency(\.audioPlayer.play) var play
  // …
}
```

This can allow your features to better describe the minimal interface they need from dependencies,
which can help a feature to seem less intimidating.

## Overriding dependencies

It is possible to change the dependencies for just one particular reducer inside a larger composed
reducer. This can be handy when running a feature in a more controlled environment where it may not be
appropriate to communicate with the outside world.

For example, suppose you want to teach users how to use your feature through an onboarding
experience. In such an experience it may not be appropriate for the user's actions to cause
data to be written to disk, or user defaults to be written, or any number of things. It would be
better to use mock versions of those dependencies so that the user can interact with your feature
in a fully controlled environment.

To do this you can use the ``ReducerProtocol/dependency(_:_:)`` method to override a reducer's
dependency with another value:

```swift
struct Onboarding: ReducerProtocol {
  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in 
      // Additional onboarding logic
    }
    Feature()
      .dependency(\.userDefaults, .mock)
      .dependency(\.database, .mock)
  }
}
```

This will cause the `Feature` reducer to use a mock user defaults and database dependency, as well
as any reducer `Feature` uses under the hood, _and_ any effects produced by `Feature`.

[swift-identified-collections]: https://github.com/pointfreeco/swift-identified-collections
[environment-values-docs]: https://developer.apple.com/documentation/swiftui/environmentvalues
[xctest-dynamic-overlay-gh]: http://github.com/pointfreeco/xctest-dynamic-overlay
