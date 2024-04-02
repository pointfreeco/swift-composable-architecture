# Migrating to 1.8

Update your code to make use of the new capabilities of the ``Reducer()`` macro, including automatic
fulfillment of requirements for destination reducers and path reducers.

## Overview

The Composable Architecture is under constant development, and we are always looking for ways to
simplify the library, and make it more powerful. This version of the library only introduced new 
APIs and did not deprecate any existing APIs. However, to make use of these tools your features
must already be integrated with the ``Reducer()`` macro from version 1.4. See <doc:MigratingTo1.4>
for more information.

## Automatic fulfillment of reducer requirements

The ``Reducer()`` macro is now capable of automatically filling in the ``Reducer`` protocol's
requirements for you. For example, even something as simple as this:

```swift
@Reducer
struct Feature {
}
```

…now compiles.

The `@Reducer` macro will automatically insert an empty ``Reducer/State`` struct, an empty 
``Reducer/Action`` enum, and an empty ``Reducer/body-swift.property``. This effectively means that
`Feature` is a logicless, behaviorless, inert reducer.

Having these requirements automatically fulfilled for you can be handy for slowly
filling them in with their real implementations. For example, this `Feature` reducer could be
integrated in a parent domain using the library's navigation tools, all without having implemented
any of the domain yet. Then, once we are ready we can start implementing the real logic and
behavior of the feature.

## Destination and path reducers

There is a common pattern in the Composable Architecture of representing destinations a feature
can navigate to as a reducer that operates on enum state, with a case for each feature that can
be navigated to. This is explained in great detail in the <doc:TreeBasedNavigation> and 
<doc:StackBasedNavigation> articles.

This form of domain modeling can be very powerful, but also incur a bit of boilerplate. For example,
if a feature can navigate to 3 other features, then one might have a `Destination` reducer like 
the following:

```swift
@Reducer
struct Destination {
  @ObservableState
  enum State {
    case add(FormFeature.State)
    case detail(DetailFeature.State)
    case edit(EditFeature.State)
  }
  enum Action {
    case add(FormFeature.Action)
    case detail(DetailFeature.Action)
    case edit(EditFeature.Action)  
  }
  var body: some ReducerOf<Self> {
    Scope(state: \.add, action: \.add) {
      FormFeature()
    }
    Scope(state: \.detail, action: \.detail) {
      DetailFeature()
    }
    Scope(state: \.edit, action: \.edit) {
      EditFeature()
    }
  }
}
```

It's not the worst code in the world, but it is 24 lines with a lot of repetition, and if we need
to add a new destination we must add a case to the ``Reducer/State`` enum, a case to the 
``Reducer/Action`` enum, and a ``Scope`` to the ``Reducer/body-swift.property``. 

The ``Reducer()`` macro is now capable of generating all of this code for you from the following
simple declaration:

```swift
@Reducer
enum Destination {
  case add(FormFeature)
  case detail(DetailFeature)
  case edit(EditFeature) 
}
```

24 lines of code has become 6. The `@Reducer` macro can now be applied to an _enum_ where each
case holds onto the reducer that governs the logic and behavior for that case.

> Note: If the parent feature has equatable state, you must extend the generated `State` of the
> enum reducer to be `Equatable` as well. Due to a bug in Swift 5.9 that prevents this from being
> done in the same file with an explicit extension, we provide the following configuration options,
> ``Reducer(state:action:)``, instead, which can be told which synthesized conformances to apply:
>
> ```swift
> @Reducer(state: .equatable)
> ```

Further, when using the ``Reducer/ifLet(_:action:)`` operator with this style of `Destination` enum
reducer you can completely leave off the trailing closure as it can be automatically inferred:

```diff
 Reduce { state, action in
   // Core feature logic
 }
-.ifLet(\.$destination, action: \.destination) {
-   Destination()
-}
+.ifLet(\.$destination, action: \.destination)
```

The same simplifications can be made to `Path` reducers when using navigation stacks, as detailed
in <doc:StackBasedNavigation>. However, there is an additional super power that comes with
`@Reducer` to further simplify constructing navigation stacks.

Typically in stack-based applications you would model a single `Path` reducer that encapsulates all
of the logic and behavior for each screen that can be pushed onto the stack. This can now be done
in a super concise syntax thanks to the new powers of `@Reducer`:

```swift
@Reducer
enum Path {
  case detail(DetailFeature)
  case meeting(MeetingFeature)
  case record(RecordFeature)
}
```

And in this case you can now leave off the trailing closure of the
``Reducer/forEach(_:action:)`` operator:

```diff
 Reduce { state, action in
   // Core feature logic
 }
-.forEach(\.path, action: \.path) {
-   Path()
-}
+.forEach(\.path, action: \.path)
```

But there's another part to path reducers that can also be simplified. When constructing the
`NavigationStack` we need to specify a trailing closure that switches on the `Path.State` enum
and decides what view to drill-down to. Currently it can be quite verbose to do this:

```swift
NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
  // Root view
} destination: { store in
  switch store.state {
  case .detail:
    if let store = store.scope(state: \.detail, action: \.detail) {
      DetailView(store: store)
    }
  case .meeting:
    if let store = store.scope(state: \.meeting, action: \.meeting) {
      MeetingView(store: store)
    }
  case .record:
    if let store = store.scope(state: \.record, action: \.record) {
      RecordView(store: store)
    }
  }
}
```

This requires a two-step process of first destructuring the `Path.State` enum to figure out which
case the state is in, and then further scoping the store down to a particular case of the
`Path.State` enum. And since such extraction is failable, we have to `if let` unwrap the scoped
store, and only then can we pass it to the child view being navigated to.

The new super powers of the `@Reducer` macro greatly improve this code. The macro adds a
``Store/case`` computed property to the store so that you can switch on the `Path.State` enum _and_
extract out a store in one step:

```swift
NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
  // Root view
} destination: { store in
  switch store.case {
  case let .detail(store):
    DetailView(store: store)
  case let .meeting(store):
    MeetingView(store: store)
  case let .record(store):
    RecordView(store: store)
  }
}
```

This is far simpler, and comes for free when using the `@Reducer` macro on your enum `Path`
reducers.
