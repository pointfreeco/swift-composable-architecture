# Migrating to 1.8

Update your code to make use of the new capabilities of the ``Reducer(state:action:)`` macro,
including automatic fulfillment of requirements for destination reducers and path reducers.

## Overview

The Composable Architecture is under constant development, and we are always looking for ways to
simplify the library, and make it more powerful. This version of the library only introduced new 
APIs and did not deprecate any existing APIs. However, to make use of these tools your features
must already be integrated with the ``Reducer(state:action:)`` macro from version 1.4. See 
<doc:MigratingTo1.4> for more information.

## Automatic fulfillment of reducer requirements

The ``Reducer(state:action:)`` macro is now capable of automatically filling in the ``Reducer`` 
protocol's requirements for you. For example, even something as simple as this:

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

The ``Reducer(state:action:)`` macro is now capable of generating all of this code for you from
the following simple declaration

```swift
@Reducer
enum Destination {
  case add(FormFeature)
  case detail(DetailFeature)
  case edit(EditFeature) 
}
```

24 lines of code has become 6. The `@Reducer` macro can now be applied to an _enum_ where each
case holds onto the reducer that governs the logic and behavior for that case. Further, when
using the ``Reducer/ifLet(_:action:)`` operator with this style of `Destination` enum reducer
you can completely leave off the trailing closure as it can be automatically inferred:

```diff
 Reduce { state, action in
   // Core feature logic
 }
-.ifLet(\.$destination, action: \.destination) {
-   Destination()
-}
+.ifLet(\.$destination, action: \.destination)
```

This pattern also works for `Path` reducers, which is common when dealing with 
<doc:StackBasedNavigation>, and in that case you can leave off the trailing closure of the
``Reducer/forEach(_:action:)`` operator:

```diff
 Reduce { state, action in
   // Core feature logic
 }
-.forEach(\.path, action: \.path) {
-   Destination()
-}
+.forEach(\.path, action: \.path)
```
