# Dependencies

Learn how to register dependencies with the library so that they can be immediately accessibly from
any reducer.

## Overview

Dependencies in an application are the types and functions that need to interact with outside 
systems that you do not control. Classic examples of this are API clients that make network requests
to servers, but also seemingly innocuous things such as `UUID` and `Date` initializers, and even
schedulers and clocks, can be thought of as dependencies.

By controlling the dependencies our features need to do their job we gain the ability to completely
alter the execution context a features runs in. This means in tests and Xcode previews you can 
provide a mock version of an API client that immediately returns some stubbed data rather than 
making a live network request to a server.

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

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    switch action {
    case .addButtonTapped:
      state.todos.append(Todo(id: UUID())
      return .none

    // ...
    }
  }
}
```

> Note: We are using `IdentifiedArray` from our 
[Identified Collections][swift-identified-collections] library because it provides a safe and
ergonomic API for accessing elements from a stable ID rather than positional indices.

In the reducer we are using the uncontrolled `UUID` initializer from Foundation. Every invocation
of the initial produces a fully random UUID. That may seem like what we want, but unfortunately
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

The library comes with a controller UUID generator and can be accessed by using the 
[`@Dependency`][dependency-property-wrapper-docs] property wrapper to add a dependency to the 
`Todos` reducer:

```swift
struct Todos: ReducerProtocol {
  @Dependency(\.uuid) var uuid
  // ...
}
```

Then when you need a new UUID you should reach for the dependency rather than reaching for the 
uncontrollable UUID initializer:

```swift
func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
  switch action {
  case .addButtonTapped:
    state.todos.append(Todo(id: self.uuid()) // ⬅️
    return .none

  // ...
  }
}
```

If you do this little bit of upfront work you instantly unlock the ability to test the feature by
providing a controlled, deterministic version of the UUID generator in tests. The library even comes
with such a version for the UUID generator, and it is called `incrementing`:

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

The library comes with many common dependencies that can be used in a controllable manner. A full
list can be seen in the documentation for [`DependencyValues`][dependency-values-docs].

For example, suppose you have a feature that needs access to a date initializer, the main queue
for time-based asynchrony, and a UUID initializer. All 3 dependencies can be added to your feature's
reducer:

```swift
struct Todos: ReducerProtocol {
  struct State {
    // ...
  }
  enum Action {
    // ...
  }
  @Dependency(\.date) var date
  @Dependency(\.mainQueue) var mainQueue
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

  store.dependencies.date = .constant(Date(timeIntervalSinceReferenceDate: 0))
  store.dependencies.mainQueue = .immediate
  store.dependencies.uuid = .incrementing

  // ...
}
```

## Registering your own dependencies

Although the library comes with many controllable dependencies out of the box, there are still 
times when you want to register your own dependencies with the library so that you can use the
`@Dependency` property wrapper. Doing this is quite similar to registering an environment value
in SwiftUI (see [docs][environment-values-docs]).

First you create a type that conforms to the [`TestDependencyKey`][test-dependency-key-docs]
protocol. The only requirement is that you provide a `testValue`, which will be the version of the
dependency used when your feature is run in a ``TestStore``:

```swift
private enum APIClientKey: TestDependencyKey {
  static let testValue = APIClient.unimplemented
}
```

We recommend having an "unimplemented" version of your dependency, that is, an implementation
that triggers an `XCTFail` anytime one of its endpoints is invoked. This makes it so that you can
stub the bare minimum of the dependency's interface, allowing you to prove that your test flow
doesn't interact with any other endpoints.

> Tip: To use a different, default version when your feature is run in an Xcode preview, use the
> optional `previewValue` requirement.
>
> ```swift
> extension APIClientKey {
>   static let previewValue = APIClient.mock(.loggedIn)
> }
> ```

Next you extend the key to also conform to the [`DependencyKey`][dependency-key-docs] protocol,
which will be the version of the dependency used when your feature is run in an Xcode preview, in
the simulator, or on a device:

```swift
extension APIClientKey: DependencyKey {
  static let liveValue = APIClient.live
}
```

This is the version of the dependency that can actually interact with outside systems. In this
case it means the API client can actually make network requests to an external server.

Finally, an extension must be made to [`DependencyValues`][dependency-values-docs] to expose a
computed property for the dependency:

```swift
extension DependencyValues {
  var apiClient: APIClient {
    get { self[APIClientKey.self] }
    set { self[APIClientKey.self] = newValue }
  }
}
```

With those few steps completed you can instantly access your API client dependency from any 
feature's reducer by using the [`@Dependency`][dependency-property-wrapper-docs] property wrapper:

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

## Designing dependencies

## Overriding dependencies

## Unimplemented dependencies

TODO: get urls

[dependency-values-docs]: get-url
[swift-identified-collections]: https://github.com/pointfreeco/swift-identified-collections
[dependency-property-wrapper-docs]: get-url
[environment-values-docs]: https://developer.apple.com/documentation/swiftui/environmentvalues
[test-dependency-key-docs]: get-url
[dependency-key-docs]: get-url
