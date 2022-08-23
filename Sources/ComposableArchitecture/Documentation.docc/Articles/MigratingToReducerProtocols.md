# Migrating to protocol reducers

Learn how to migrate existing applications to use the new `ReducerProtocol`, in both Swift 5.7 and
Swift 5.6.

## Overview

The ``ReducerProtocol`` makes use of many new features of Swift 5.7, including primary associated 
types and constrained opaque types. If you are already using Swift 5.7+, then you can start making 
use of these features right away. If you are using Swift 5.6 then you can still make use of 
``ReducerProtocol``, but with a few minor tweaks.

## Migration using Swift 5.7

The ``Reducer`` type that allows you to construct a reducer from a closure, and has been around 
since the very first version of the library, is now officially considered "soft-deprecated." This 
means that it will not show deprecation warnings in your code yet, but some day in the future we 
will mark it deprecated, and then someday later remove the type from the library. This process will 
take place over a long period of time, giving everyone enough time to migrate their applications.

There are a few strategies you can follow to slowly convert all usages of ``Reducer`` to the new
protocol-style reducers. It does not need to be done all at once, and instead can be done in a 
piecemeal fashion.

### Leaf node features

The simplest parts of an application to convert to ``ReducerProtocol`` are leaf node features that 
do not compose multiple reducers at once. For example, suppose you have a feature domain with some 
dependencies like this:

```swift
struct MyFeatureState {
  // ...
}

enum MyFeatureAction {
  // ...
}

struct MyFeatureEnvironment {
  var apiClient: APIClient
  var date: () -> Date
}

let myFeatureReducer = Reducer<
  MyFeatureState,
  MyFeatureAction,
  MyFeatureEnvironment
> { state, action, environment in
  switch action {
  // ...
  }
}
```

You can convert this to the protocol style by:

1. Creating a dedicated type that conforms to the ``ReducerProtocol``.
1. Nest the state and action types inside this new type, and rename them to just `State` and 
`Action`.
1. Move the fields on the environment to be fields on this new reducer type, and delete the 
environment type.
1. Move the reducer's closure implementation to the ``ReducerProtocol/reduce(into:action:)-76g02`` 
method.

Performing these 4 steps on the feature produces the following:

```swift
struct MyFeature: ReducerProtocol {
  struct State {
    // ...
  }

  enum Action {
    // ...
  }

  let apiClient: APIClient
  let date: () -> Date

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    switch action {
    // ...
    }
  }
}
```

Once this feature's domain and reducer is converted to the new style you will invariably have 
compiler errors wherever you were referring to the old types. For example, suppose you have a 
parent feature that embeds this child feature into it:

```swift
struct ParentState { 
  var myFeature: MyFeatureState
  // ...
}

enum ParentAction {
  case myFeature(MyFeatureAction)
  // ...
}

struct ParentEnvironment {
  var date: () -> Date
  var dependency: Dependency
  // ...
}

let parentReducer = Reducer<ParentState, ParentAction, ParentEnvironment>.combine(
  myFeatureReducer
    .pullback(
      state: \.featureA, 
      action: /ParentAction.featureA, 
      environment: {  
        FeatureAEnvironment(date: $0.date, dependency: $0.dependency)
      }
    ),

  Reducer { state, action, environment in 
    // ...
  }
)
```

This can be updated to work with the new `FeatureA` reducer type by first fixing any references to 
the state and action types:

```swift
struct ParentState { 
  var myFeature: MyFeature.State
  // ...
}

enum ParentAction {
  case myFeature(MyFeature.Action)
  // ...
}
```

And then the `parentReducer` can be fixed by making use of the helper ``AnyReducer/init(_:)`` which
aids in converting protocol-style reducers into old-style reducers. It is initialized with a closure 
that is passed an environment, which is the one thing protocol-style reducers don't have, and you 
are to return a protocol-style reducer:

```swift
let parentReducer = Reducer<ParentState, ParentAction, ParentEnvironment>.combine(
  AnyReducer {
    MyFeature(
      apiClient: $0.apiClient,
      date: $0.date
    )
    .pullback(state: \.featureA, action: /ParentAction.featureA)
  },

  Reducer { state, action, environment in 
    // ...
  }
)
```

With those few changes your application should now build, and you have successfully converted one
leaf node feature to the new style of ``ReducerProtocol``.

### Composition of features

Some features in your application are an amalgamation of other features. For example, a tab-based
application may have a separate domain and reducer for each tab, and then a app-level domain and
reducer that composes everything together.

Suppose that all of the tab features have already be converted to the protocol-style:

```swift
struct TabA: ReducerProtocol {
  struct State {
    // ...
  }
  enum Action {
    // ...
  }
  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    // ...
  }
}

struct TabB: ReducerProtocol {
  // ...
}

struct TabC: ReducerProtocol {
  // ...
}
```

But, suppose that the app-level domain and reducer has not yet be converted and so has compiler 
errors due to referencing types and values that no longer exist:

```swift
struct AppState {
  var tabA: TabAState
  var tabB: TabBState
  var tabC: TabCState
}

enum AppAction {
  case tabA(TabAAction)
  case tabB(TabBAction)
  case tabC(TabCAction)
}

struct AppEnvironment {}

let appReducer = Reducer<
  AppState, 
  AppAction, 
  AppEnvironment
> { state, action, environment in 
  // ...
}
```

To convert this to the protocol-style we again introduce a new type that conforms to the 
``ReducerProtocol``, we nest the domain types inside the conformance, we inline the environment
fields, but this time we use the ``ReducerProtocol/body-swift.property-7foai`` requirement of the
protocol to describe how to compose multiple reducers:

```swift
struct AppReducer: ReducerProtocol {
  struct State {
    var tabA: TabA.State
    var tabB: TabB.State
    var tabC: TabC.State
  }

  enum Action {
    case tabA(TabA.Action)
    case tabB(TabB.Action)
    case tabC(TabC.Action)
  }

  var body: some ReducerProtocol<State, Action> {
    Scope(state: \.tabA, action: /Action.tabA) {
      TabA()
    }
    Scope(state: \.tabB, action: /Action.tabC) {
      TabB()
    }
    Scope(state: \.tabB, action: /Action.tabC) {
      TabC()
    }
  }
}
```

With those few small changes we have now converted a composition of many reducers into the new
protocol-style.

### Dependencies

In the previous sections we inlined all dependencies directly into the conforming type:

```swift
struct MyFeature: ReducerProtocol {
  let apiClient: APIClient
  let date: () -> Date
  // ...
}
```

But this means that you must explicitly thread all dependencies from the root of the application
through to every child feature. This can be arduous and make it difficult to add, remove or change
dependencies.

The library comes with a tool for managing dependencies in a more ergonomic manner, and even comes
with some common dependencies pre-integrated allowing you to access them with no additional work.
For example, the `date` dependency ships with the library so that you can declare your feature's
dependence on that functionality in the following way:

```swift
struct MyFeature: ReducerProtocol {
  let apiClient: APIClient
  @Dependency(\.date) var date
  // ...
}
```

With that one declaration you can stop explicitly passing the date dependency through every layer
of your application. A date function will be automatically provided to your feature's reducer.

For domain-specific dependencies you can perform a little bit of upfront work to register your
dependency with the system, and then it will be automatically available to every layer in your 
application:

```swift
private enum APIClientKey: LiveDependencyKey {
  static let liveValue = APIClient.live
  static let testValue = APIClient.unimplemented
}
extension DependencyValues {
  var apiClient: APIClient {
    get { self[APIClientKey.self] }
    set { self[APIClientKey.self] = newValue }
  }
}
```

With that work done you can access the dependency from any feature's reducer using the `@Dependency`
property wrapper:

```swift
struct MyFeature: ReducerProtocol {
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.date) var date
  // ...
}
```

For more information on designing your dependencies and providing live and test dependencies, see
our <doc:Testing> article.

### Stores

Stores can be initialized from an initial state and an instance of a type conforming to
``ReducerProtocol``:

```swift
MyFeatureView(
  store: Store(
    initialState: MyFeature.State(),
    reducer: MyFeature()
  )
)
```

Views that hold onto stores can also employ the ``StoreOf`` type alias to clean up the property
declaration:

```swift
let store: StoreOf<MyFeature>
// Expands to:
//     let store: Store<MyFeature.State, MyFeature.Action>
```

### Testing

Test stores can be initialized from an initial state and an instance of a type conforming to
``ReducerProtocol``.

```swift
let store = TestStore(
  initialState: MyFeature.State(),
  reducer: MyFeature()
)
```

By default test stores will employ "test" dependencies wherever a dependency is accessed from a
reducer via the `@Dependency` property wrapper.

Instead of passing an environment of test dependencies to the store, or mutating the store's
``TestStore/environment``, you will instead mutate the test store's ``TestStore/dependencies`` to
override dependencies driving a feature.

For example, to install a test scheduler as the main queue dependency:

```swift
let mainQueue = DispatchQueue.test
store.dependencies.mainQueue = mainQueue

await store.send(.timerButtonStarted)

await mainQueue.advance(by: .seconds(1))
await store.receive(.timerTick) {
  $0.secondsElapsed = 1
}

await store.send(.timerButtonStopped)
```

### Embedding old reducer values in a new reducer conformance

It may not be feasible to migrate your entire application at once, and you may find yourself
needing to compose an existing value of ``Reducer`` into a type conforming to ``ReducerProtocol``.
This can be done by passing the value and its environment of dependencies to
``Reduce/init(_:environment:)``.

For example, suppose a tab of your application has not yet been converted to the protocol-style of
reducers, and it has an environment of dependencies:

```swift
struct TabCState {
  // ...
}
enum TabCAction {
  // ...
}
struct TabCEnvironment {
  var date: () -> Date
}
let tabCReducer = Reducer<
  TabCState,
  TabCAction,
  TabCEnvironment
} { state, action, environment in
  // ...
}
```

It can still be embedded in `AppReducer` using ``Reduce/init(_:environment:)`` and passing along the
necessary dependencies.

```swift
struct AppReducer: ReducerProtocol {
  struct State {
    // ...
    var tabC: TabCState
  }

  enum Action {
    // ...
    case tabC(TabCAction)
  }

  @Dependency(\.date) var date

  var body: some ReducerProtocol<State, Action> {
    // ...
    Scope(state: \.tabC, action: /Action.tabC) {
      Reduce(
        tabCReducer,
        environment: TabCEnvironment(date: self.date)
      )
    }
  }
}
```

## Migration using Swift 5.6

The migration strategy described above for Swift 5.7 also applies to applications that are still 
using Xcode 13 and Swift 5.6, but with one small change. When conforming your types to the 
``ReducerProtocol`` you are not allowed to use the `some ReducerProtocol<State, Action>` syntax
because that is only available in Swift 5.7. Instead, you must specify `Reduce<State, Action>`
as the type of the `body` property:

```swift
struct AppReducer: ReducerProtocol {
  // ...
  var body: Reduce<State, Action> {
    FeatureA()
    FeatureB()
    FeatureC()
  }
}
```

The ``Reduce`` type is like a type-erased reducer that allows you to construct a reducer from a 
closure. In Swift 5.6, the ``ReducerBuilder`` will automatically erase the reducer you build for 
you so that you do not have to worry about specifying its type explicitly. This may come with a 
slight performance cost compared to using full opaque types for `body`, but should be of comparable 
performance to reducers using the ``Reducer`` type, which is now soft-deprecated.

All other features of the library should work in Swift 5.6 without any other changes. This includes 
`@Dependency` and all dependency management tools.
