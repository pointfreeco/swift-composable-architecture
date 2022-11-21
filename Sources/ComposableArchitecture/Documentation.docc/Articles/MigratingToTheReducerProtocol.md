# Migrating to the reducer protocol

Learn how to migrate existing applications to use the new ``ReducerProtocol``, in both Swift 5.7 and
Swift 5.6.

## Overview

Migrating an application that uses the ``Reducer`` type over to the new ``ReducerProtocol`` can be
done slowly and incrementally. The library provides the tools to convert one reducer at a time,
allowing you to plug protocol-style reducers into old-style reducers, and vice-versa.

Although we recommend migrating your code when you have time, the newest version of the library
is still 100% backwards compatible with all previous versions. The ``Reducer`` type is now
"soft" deprecated, which means we consider it deprecated, and it says so in the documentation, but 
you will not get any warnings about it. Sometime in the future, we will officially deprecate it, 
and then sometime even later we will remove it so that we can rename the protocol to `Reducer`.

This article outlines a number of strategies you can employ to convert your reducers to the protocol
when you are ready:

* [Leaf node features](#Leaf-node-features)
* [Composition of features](#Composition-of-features)
* [Optional and pullback reducers](#Optional-and-pullback-reducers)
* [For-each reducers](#For-each-reducers)
* [Binding reducers](#Binding-reducers)
* [Dependencies](#Dependencies)
* [Stores](#Stores)
* [Testing](#Testing)
* [Embedding old reducer values in a new reducer conformance](#Embedding-old-reducer-values-in-a-new-reducer-conformance)
* [Migration using Swift 5.6](#Migration-using-Swift-56)

## Leaf node features

The simplest parts of an application to convert to ``ReducerProtocol`` are leaf node features that 
do not compose multiple reducers at once. For example, suppose you have a feature domain with a 
dependency like this:

```swift
struct FeatureState {
  // ...
}
enum FeatureAction {
  // ...
}
struct FeatureEnvironment {
  var date: () -> Date
}

let featureReducer = Reducer<
  FeatureState,
  FeatureAction,
  FeatureEnvironment
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
1. Move the reducer's closure implementation to the ``ReducerProtocol/reduce(into:action:)-8yinq`` 
method.

Performing these 4 steps on the feature produces the following:

```swift
struct Feature: ReducerProtocol {
  struct State {
    // ...
  }

  enum Action {
    // ...
  }

  let date: () -> Date

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    // ...
    }
  }
}
```

Once this feature's domain and reducer are converted to the protocol-style you will invariably have 
compiler errors wherever you were referring to the old types. For example, suppose you have a 
parent feature that is currently trying to embed the old-style domain and reducer into its domain
and reducer:

```swift
struct ParentState { 
  var feature: FeatureState
  // ...
}

enum ParentAction {
  case feature(FeatureAction)
  // ...
}

struct ParentEnvironment {
  var date: () -> Date
  var dependency: Dependency
  // ...
}

let parentReducer = Reducer<ParentState, ParentAction, ParentEnvironment>.combine(
  featureReducer
    .pullback(
      state: \.feature, 
      action: /ParentAction.feature, 
      environment: {  
        FeatureEnvironment(date: $0.date)
      }
    ),

  Reducer { state, action, environment in 
    // ...
  }
)
```

This can be updated to work with the new `Feature` reducer conformance by first fixing any 
references to the state and action types:

```swift
struct ParentState { 
  var feature: Feature.State
  // ...
}

enum ParentAction {
  case feature(Feature.Action)
  // ...
}
```

And then the `parentReducer` can be fixed by making use of the helper ``AnyReducer/init(_:)-42p1a``
which aids in converting protocol-style reducers into old-style reducers. It is initialized with a
closure that is passed an environment, which is the one thing protocol-style reducers don't have,
and you  are to return a protocol-style reducer:

```swift
let parentReducer = Reducer<ParentState, ParentAction, ParentEnvironment>.combine(
  AnyReducer { environment in
    Feature(date: environment.date)
  }
  .pullback(
    state: \.feature, 
    action: /ParentAction.feature, 
    environment: { $0 }
  ),

  Reducer { state, action, environment in 
    // ...
  }
)
```

Note that the ``AnyReducer``'s only purpose is to convert the protocol-style reducer to the 
old-style so that it can be plugged into existing old-style reducers. You can then chain on the 
operators you were using before to the end of the ``AnyReducer`` usage.

With those few changes your application should now build, and you have successfully converted one
leaf node feature to the new ``ReducerProtocol``-style of doing things.

## Composition of features

Some features in your application are an amalgamation of other features. For example, a tab-based
application may have a separate domain and reducer for each tab, and then an app-level domain and
reducer that composes everything together.

Suppose that all of the tab features have already been converted to the protocol-style:

```swift
struct TabA: ReducerProtocol {
  struct State {
    // ...
  }
  enum Action {
    // ...
  }
  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
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

But, suppose that the app-level domain and reducer have not yet been converted and so have compiler 
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

## Optional and pullback reducers

A common pattern in the Composable Architecture is to model a feature that can be presented and 
dismissed as optional state. For example, suppose you have the feature's domain and reducer modeled
like so:

```swift
struct FeatureState { 
  // ...
}
struct FeatureAction { 
  // ...
}
struct FeatureEnvironment { 
  var date: () -> Date
}

let featureReducer = Reducer<
  FeatureState, 
  FeatureAction, 
  FeatureEnvironment
> { state, action, environment in
  // Feature logic
}
```

Then, the parent feature can embed this child feature as an optional in its state:

```swift
struct ParentState {
  var feature: FeatureState?
  // ...
}
enum ParentAction {
  case feature(FeatureAction)
  // ...
}
struct ParentEnvironment {
  var date: () -> Date
}
```

A non-`nil` value for `feature` indicates that the feature view is being presented, and when it 
switches to `nil` the view should be dismissed. The actual showing and hiding of the view can be
done using the ``IfLetStore`` SwiftUI view.

In order to construct a single reducer that can handle the logic for the parent domain as well as
allow the child feature to run its logic on the `feature` state when non-`nil`, we can make use the
``AnyReducer/optional(file:fileID:line:)`` and ``AnyReducer/pullback(state:action:environment:)``
operators:

```swift
let parentReducer = Reducer<
  ParentState,
  ParentAction,
  ParentEnvironment
>.combine( 
  featureReducer
    .optional()
    .pullback(
      state: \.feature, 
      action: /ParentAction.feature, 
      environment: { FeatureEnvironment(date: $0.date) }
    ),

  Reducer { state, action, environment in
    // Parent logic
  }
)
```

It seems complex, but we have now combined the logic for the parent feature and child feature into
one package, and the child feature will only run when the state is non-`nil`.

Migrating the `featureReducer` to the protocol by following the earlier instructions will
yield a new `Feature` type that conforms to ``ReducerProtocol``, and the `parentReducer` will
look something like this:

```swift
let parentReducer = Reducer<
  ParentState,
  ParentAction,
  ParentEnvironment
>.combine( 
  AnyReducer { environment in
    Feature(date: environment.date)
  }
  .optional()
  .pullback(
    state: \.feature, 
    action: /ParentAction.feature, 
    environment: { FeatureEnvironment(date: $0.date) }
  ),

  Reducer { state, action, environment in
    // Parent logic
  }
)
```

Now the question is, how do we migrate `parentReducer` to a protocol conformance?

This gives us an opportunity to improve the correctness of this code. It turns out there is a gotcha 
with the `optional` operator: it must be run _before_ the parent logic runs. If it is not, then it 
is possible for a child action to come into the system, the parent observes the action and decides to 
`nil` out the child state, and then the child reducer will not get a chance to react to the action.
This can cause subtle bugs, and so we have documentation advising you to order things the correct 
way, and if we detect a child action while state is `nil` we display a runtime warning.

A `Parent` reducer conformances can be made by implementing the 
``ReducerProtocol/body-swift.property-7foai`` property of the ``ReducerProtocol``, which allows you
to express the parent's logic as a composition of multiple reducers. In particular, you can use
the ``Reduce`` entry point to implement the core parent logic, and then chain on the 
``ReducerProtocol/ifLet(_:action:then:file:fileID:line:)`` operator to identify the optional child
state that you want to run the `Feature` reducer on when non-`nil`:

```swift
struct Parent: ReducerProtocol {
  struct State {
    var feature: Feature.State?
    // ...
  }
  enum Action {
    case feature(Feature.Action)
    // ...
  }

  let date: () -> Date

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      // Parent logic
    }
    .ifLet(\.feature, action: /Action.feature) {
      Feature(date: self.date)
    }
  }
}
```

Because the `ifLet` operator has knowledge of both the parent and child reducers it can enforce the
order to add an additional layer of correctness.

If you are using an enum to model your state, then there is a corresponding 
``ReducerProtocol/ifCaseLet(_:action:then:file:fileID:line:)`` operator that can help you run a
reducer on just one case of the enum.

## For-each reducers

Similar to `optional` reducers, another common pattern in applications is the use of the 
``AnyReducer/forEach(state:action:environment:file:fileID:line:)-2ypoa`` to allow running a reducer
on each element of a collection. Converting such child and parent reducers will look nearly
identical to what we did above for optional reducers, but it will make use of the new
``ReducerProtocol/forEach(_:action:_:file:fileID:line:)`` operator instead.

In particular, the new `forEach` method operates on the parent reducer by specifying the collection
sub-state you want to work on, and providing the element reducer you want to be able to run on
each element:

```swift
struct Parent: ReducerProtocol {
  struct State {
    var rows: IdentifiedArrayOf<Feature.State>
    // ...
  }
  enum Action {
    case row(id: Feature.State.ID, action: Feature.Action)
    // ...
  }

  let date: () -> Date

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      // Parent logic
    }
    .forEach(\.rows, action: /Action.row) {
      Feature(date: self.date)
    }
  }
}
```

## Binding reducers

Previously, reducers with bindable state and a binding action used the `Reducer.binding()` method
to automatically make mutations to state before running the main logic of a reducer.

```swift
Reducer { state, action, environment in
  // Logic to run after bindable state mutations are applied
}
.binding()
```

In reducer builders, use the new top-level ``BindingReducer`` type to specify when to apply
mutations to bindable state:

```swift
var body: some ReducerProtocol<State, Action> {
  Reduce { state, action in
    // Logic to run before bindable state mutations are applied
  }

  BindingReducer()  // Apply bindable state mutations

  Reduce { state, action in
    // Logic to run after bindable state mutations are applied
  }
}
```

## Dependencies

In the previous sections we inlined all dependencies directly into the conforming type:

```swift
struct Feature: ReducerProtocol {
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
struct Feature: ReducerProtocol {
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
private enum APIClientKey: DependencyKey {
  static let liveValue = APIClient.live
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
struct Feature: ReducerProtocol {
  @Dependency(\.apiClient) var apiClient
  @Dependency(\.date) var date
  // ...
}
```

For more information on designing your dependencies and providing live and test dependencies, see
our <doc:Testing> article.

## Stores

Stores can be initialized from an initial state and an instance of a type conforming to
``ReducerProtocol``:

```swift
FeatureView(
  store: Store(
    initialState: Feature.State(),
    reducer: Feature()
  )
)
```

Views that hold onto stores can also employ the ``StoreOf`` type alias to clean up the property
declaration:

```swift
let store: StoreOf<Feature>
// Expands to:
//     let store: Store<Feature.State, Feature.Action>
```

## Testing

Test stores can be initialized from an initial state and an instance of a type conforming to
``ReducerProtocol``.

```swift
let store = TestStore(
  initialState: Feature.State(),
  reducer: Feature()
)
```

By default test stores will employ "test" dependencies wherever a dependency is accessed from a
reducer via the `@Dependency` property wrapper.

Instead of passing an environment of test dependencies to the store, or mutating the store's
``TestStore/environment``, you will instead mutate the test store's ``TestStore/dependencies`` to
override dependencies driving a feature.

For example, to install a test clock as the continuous clock dependency you can do the following:

```swift
let clock = TestClock()
store.dependencies.continuousClock = clock

await store.send(.timerButtonStarted)

await clock.advance(by: .seconds(1))
await store.receive(.timerTick) {
  $0.secondsElapsed = 1
}

await store.send(.timerButtonStopped)
```

## Embedding old reducer values in a new reducer conformance

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
``ReducerProtocol`` you are not allowed to use the syntax `some ReducerProtocol<State, Action>` 
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
