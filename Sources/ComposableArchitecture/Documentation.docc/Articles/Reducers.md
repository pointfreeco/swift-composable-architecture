# Reducers

Learn about one of the most fundamental tools in the Composable Architecture: the reducer. It is
responsible for evolving the state of your application forward when an action is sent, and 
constructing effects that are executed in the outside world.

## Overview

The ``Reducer`` protocol describes how to evolve the current state of an application to the next
state, given an action, and describes what ``Effect``s should be executed later by the store, if
any. Types that conform to this protocol represent the domain, logic and behavior for a feature.
Conformances to ``Reducer`` can be written by hand, but the ``Reducer()`` can make your reducers 
more concise and more powerful.

* [Conforming to the Reducer protocol](#Conforming-to-the-Reducer-protocol)
* [Using the @Reducer macro](#Using-the-Reducer-macro)
  * [@CasePathable and @dynamicMemberLookup enums](#CasePathable-and-dynamicMemberLookup-enums)
  * [Automatic fulfillment of reducer requirements](#Automatic-fulfillment-of-reducer-requirements)
  * [Destination and path reducers](#Destination-and-path-reducers)
    * [Navigating to non-reducer features](#Navigating-to-non-reducer-features)
    * [Synthesizing protocol conformances on State and Action](#Synthesizing-protocol-conformances-on-State-and-Action)
  * [Gotchas](#Gotchas)
    * [Autocomplete](#Autocomplete)
    * [Circular reference errors](#Circular-reference-errors)
    * [#Preview and enum reducers](#Preview-and-enum-reducers)
    * [CI build failures](#CI-build-failures)

## Conforming to the Reducer protocol

The bare minimum of conforming to the ``Reducer`` protocol is to provide a ``Reducer/State`` type
that represents the state your feature needs to do its job, a ``Reducer/Action`` type that
represents the actions users can perform in your feature (as well as actions that effects can
feed back into the system), and a ``Reducer/body-8lumc`` property that compose your feature
together with any other features that are needed (such as for navigation).

As a very simple example, a "counter" feature could model its state as a struct holding an integer:

```swift
struct CounterFeature: Reducer {
  @ObservableState
  struct State {
    var count = 0
  }
}
```

> Note: We have added the ``ObservableState()`` to `State` here so that the view can automatically
> observe state changes. In future versions of the library this macro will be automatically applied
> by the ``Reducer()`` macro.

The actions would be just two cases for tapping an increment or decrement button:

```swift
struct CounterFeature: Reducer {
  // ...
  enum Action {
    case decrementButtonTapped
    case incrementButtonTapped
  }
}
```

The logic of your feature is implemented by mutating the feature's current state when an action
comes into the system. This is most easily done by constructing a ``Reduce`` inside the
``Reducer/body-8lumc`` of your reducer:

```swift
struct CounterFeature: Reducer {
  // ...
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .decrementButtonTapped:
        state.count -= 1
        return .none
      case .incrementButtonTapped:
        state.count += 1  
        return .none
      }
    }
  }
}
```

The ``Reduce`` reducer's first responsibility is to mutate the feature's current state given an
action. Its second responsibility is to return effects that will be executed asynchronously and feed
their data back into the system. Currently `Feature` does not need to run any effects, and so
``Effect/none`` is returned.

If the feature does need to do effectful work, then more would need to be done. For example, suppose
the feature has the ability to start and stop a timer, and with each tick of the timer the `count`
will be incremented. That could be done like so:

```swift
struct CounterFeature: Reducer {
  @ObservableState
  struct State {
    var count = 0
  }
  enum Action {
    case decrementButtonTapped
    case incrementButtonTapped
    case startTimerButtonTapped
    case stopTimerButtonTapped
    case timerTick
  }
  enum CancelID { case timer }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .decrementButtonTapped:
        state.count -= 1
        return .none

      case .incrementButtonTapped:
        state.count += 1
        return .none

      case .startTimerButtonTapped:
        return .run { send in
          while true {
            try await Task.sleep(for: .seconds(1))
            await send(.timerTick)
          }
        }
        .cancellable(CancelID.timer)

      case .stopTimerButtonTapped:
        return .cancel(CancelID.timer)

      case .timerTick:
        state.count += 1
        return .none
      }
    }
  }
}
```

> Note: This sample emulates a timer by performing an infinite loop with a `Task.sleep` inside. This
> is simple to do, but is also inaccurate since small imprecisions can accumulate. It would be
> better to inject a clock into the feature so that you could use its `timer` method. Read the
> <doc:DependencyManagement> and <doc:Testing> articles for more information.

That is the basics of implementing a feature as a conformance to ``Reducer``. 

## Using the @Reducer macro

While you technically can conform to the ``Reducer`` protocol directly, as we did above, the
``Reducer()`` macro can automate many aspects of implementing features for you. At a bare minimum,
all you have to do is annotate your reducer with `@Reducer` and you can even drop the `Reducer`
conformance:

```diff
+@Reducer
-struct CounterFeature: Reducer {
+struct CounterFeature {
   @ObservableState
   struct State {
     var count = 0
   }
   enum Action {
     case decrementButtonTapped
     case incrementButtonTapped
   }
   var body: some ReducerOf<Self> {
     Reduce { state, action in
       switch action {
       case .decrementButtonTapped:
         state.count -= 1
         return .none
       case .incrementButtonTapped:
         state.count += 1  
         return .none
       }
     }
   }
 }
```

There are a number of things the ``Reducer()`` macro does for you:

#### @CasePathable and @dynamicMemberLookup enums

The `@Reducer` macro automatically applies the [`@CasePathable`][casepathable-docs] macro to your
`Action` enum:

```diff
+@CasePathable
 enum Action {
   // ...
 }
```

[Case paths][casepaths-gh] are a tool that bring the power and ergonomics of key paths to enum
cases, and they are a vital tool for composing reducers together.

In particular, having this macro applied to your `Action` enum will allow you to use key path
syntax for specifying enum cases in various APIs in the library, such as
``Reducer/ifLet(_:action:destination:fileID:line:)-4f2at``,
``Reducer/forEach(_:action:destination:fileID:line:)-yz3v``, ``Scope``, and more.

Further, if the ``Reducer/State`` of your feature is an enum, which is useful for modeling a feature
that can be one of multiple mutually exclusive values, the ``Reducer()`` will apply the
`@CasePathable` macro, as well as `@dynamicMemberLookup`:

```diff
+@CasePathable
+@dynamicMemberLookup
 enum State {
   // ...
 }
```

This will allow you to use key path syntax for specifying case paths to the `State`'s cases, as well
as allow you to use dot-chaining syntax for optionally extracting a case from the state. This can be
useful when using the operators that come with the library that allow for driving navigation from an
enum of options:

```swift
.sheet(
  item: $store.scope(state: \.destination?.editForm, action: \.destination.editForm)
) { store in
  FormView(store: store)
}
```

The syntax `state: \.destination?.editForm` is only possible due to both `@dynamicMemberLookup` and
`@CasePathable` being applied to the `State` enum.

#### Automatic fulfillment of reducer requirements

The ``Reducer()`` macro will automatically fill in any ``Reducer`` protocol requirements that you
leave off. For example, something as simple as this compiles:

```swift
@Reducer
struct Feature {}
```

The `@Reducer` macro will automatically insert an empty ``Reducer/State`` struct, an empty
``Reducer/Action`` enum, and an empty ``Reducer/body-swift.property``. This effectively means that
`Feature` is a logicless, behaviorless, inert reducer.

Having these requirements automatically fulfilled for you can be handy for slowly filling them in
with their real implementations. For example, this `Feature` reducer could be integrated in a parent
domain using the library's navigation tools, all without having implemented any of the domain yet.
Then, once we are ready we can start implementing the real logic and behavior of the feature.

#### Destination and path reducers

There is a common pattern in the Composable Architecture of representing destinations a feature can
navigate to as a reducer that operates on enum state, with a case for each feature that can be
navigated to. This is explained in great detail in the <doc:TreeBasedNavigation> and
<doc:StackBasedNavigation> articles.

This form of domain modeling can be very powerful, but also incur a bit of boilerplate. For example,
if a feature can navigate to 3 other features, then one might have a `Destination` reducer like the
following:

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

It's not the worst code in the world, but it is 24 lines with a lot of repetition, and if we need to
add a new destination we must add a case to the ``Reducer/State`` enum, a case to the
``Reducer/Action`` enum, and a ``Scope`` to the ``Reducer/body-swift.property``.

The ``Reducer()`` macro is now capable of generating all of this code for you from the following
simple declaration

```swift
@Reducer
enum Destination {
  case add(FormFeature)
  case detail(DetailFeature)
  case edit(EditFeature)
}
```

24 lines of code has become 6. The `@Reducer` macro can now be applied to an _enum_ where each case
holds onto the reducer that governs the logic and behavior for that case. Further, when using the
``Reducer/ifLet(_:action:)`` operator with this style of `Destination` enum reducer you can
completely leave off the trailing closure as it can be automatically inferred:

```diff
 Reduce { state, action in
   // Core feature logic
 }
 .ifLet(\.$destination, action: \.destination)
-{
-  Destination()
-}
```

This pattern also works for `Path` reducers, which is common when dealing with
<doc:StackBasedNavigation>, and in that case you can leave off the trailing closure of the
``Reducer/forEach(_:action:)`` operator:

```diff
Reduce { state, action in
  // Core feature logic
}
.forEach(\.path, action: \.path)
-{
-  Path()
-}
```

Further, for `Path` reducers in particular, the ``Reducer()`` macro also helps you reduce
boilerplate when using the initializer 
``SwiftUI/NavigationStack/init(path:root:destination:)`` that comes with the library. In the last
trailing closure you can use the ``Store/case`` computed property to switch on the `Path.State` enum
and extract out a store for each case:

```swift
NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
  // Root view
} destination: { store in
  switch store.case {
  case let .add(store):
    AddView(store: store)
  case let .detail(store):
    DetailView(store: store)
  case let .edit(store):
    EditView(store: store)
  }
}
```

#### Navigating to non-reducer features

There are many times that you want to present or navigate to a feature that is not modeled with a
Composable Architecture reducer. This can happen with legacy features that are not built with the
Composable Architecture, or with features that are very simple and do not need a fully built
reducer.

In those cases you can use the ``ReducerCaseIgnored()`` and ``ReducerCaseEphemeral()`` macros to
annotate cases that are not powered by reducers. See the documentation for those macros for more
details.

As an example, suppose that you have a feature that can navigate to multiple features, all of 
which are Composable Architecture features except for one:

```swift
@Reducer
enum Destination {
  case add(AddItemFeature)
  case edit(EditItemFeature)
  @ReducerCaseIgnored
  case item(Item)
}
```

In this situation the `.item` case holds onto a plain item and not a full reducer, and for that 
reason we have to ignore it from some of `@Reducer`'s macro expansion.

Then, to present a view from this case one can do:

```swift
.sheet(item: $store.scope(state: \.destination?.item, action: \.destination.item)) { store in
  ItemView(item: store.withState { $0 })
}
```

> Note: The ``Store/withState(_:)`` is necessary because the value held inside the `.item` case
does not have the ``ObservableState()`` macro applied, nor should it. And so using `withState`
is a way to get access to the state in the store without any observation taking place.

#### Synthesizing protocol conformances on State and Action

Since the `State` and `Action` types are generated automatically for you when using `@Reducer` on an
enum, it's not possible to directly synthesize conformances of `Equatable`, `Hashable`,
_etc._, on those types. And further, due to a bug in the Swift compiler you cannot currently do
this:

```swift
@Reducer
enum Destination {
  // ...
}
extension Destination.State: Equatable {}  // ❌
```

See <doc:Reducers#Circular-reference-errors> below for more info on this error.

So, to work around this compiler bug the `@Reducer` macro takes two
``ComposableArchitecture/_SynthesizedConformance`` arguments that allow you to describe which
protocols you want to attach to the `State` or `Action` types:

```swift
@Reducer(state: .equatable, .sendable, action: .sendable)
enum Destination {
  // ...
}
```

You can provide any combination of
``ComposableArchitecture/_SynthesizedConformance/codable``,
``ComposableArchitecture/_SynthesizedConformance/decodable``,
``ComposableArchitecture/_SynthesizedConformance/encodable``,
``ComposableArchitecture/_SynthesizedConformance/equatable``,
``ComposableArchitecture/_SynthesizedConformance/hashable``, or
``ComposableArchitecture/_SynthesizedConformance/sendable``.

### Gotchas

#### Autocomplete

Applying `@Reducer` can break autocompletion in the `body` of the reducer. This is a known
[issue](https://github.com/apple/swift/issues/69477), and it can generally be worked around by
providing additional type hints to the compiler:

 1. Adding an explicit `Reducer` conformance in addition to the macro application can restore
    autocomplete throughout the `body` of the reducer:

    ```diff
     @Reducer
    -struct Feature {
    +struct Feature: Reducer {
    ```

 2. Adding explicit generics to instances of `Reduce` in the `body` can restore autocomplete
    inside the `Reduce`:

    ```diff
     var body: some Reducer<State, Action> {
    -  Reduce { state, action in
    +  Reduce<State, Action> { state, action in
    ```

#### Circular reference errors

There is currently a bug in the Swift compiler and macros that prevents you from extending types
that are inside other types with macros applied in the same file. For example, if you wanted to
extend a reducer's `State` with some extra functionality:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State { /* ... */ }
  // ...
}

extension Feature.State {  // 🛑 Circular reference
  // ...
}
```

This unfortunately does not work. It is a
[known issue](https://github.com/apple/swift/issues/66450), and the only workaround is to either
move the extension to a separate file, or move the code from the extension to be directly inside the
`State` type.

#### #Preview and enum reducers

The `#Preview` macro is not capable of seeing the expansion of any macros since it is a macro 
itself. This means that when using destination and path reducers (see
<doc:Reducers#Destination-and-path-reducers> above) you cannot construct the cases of the state 
enum inside `#Preview`:

```swift
#Preview {
  FeatureView(
    store: Store(
      initialState: Feature.State(
        destination: .edit(EditFeature.State())  // 🛑
      )
    ) {
      Feature()
    }
  )
}
```

The `.edit` case is not usable from within `#Preview` since it is generated by the ``Reducer()``
macro.

The workaround is to move the view to a helper that be compiled outside of a macro, and then use it
inside the macro:

```swift
#Preview {
  preview
}
private var preview: some View {
  FeatureView(
    store: Store(
      initialState: Feature.State(
        destination: .edit(EditFeature.State())
      )
    ) {
      Feature()
    }
  )
}
```

You can use a computed property, free function, or even a dedicated view if you want. You can also
use the old, non-macro style of previews by using a `PreviewProvider`:

```swift
struct Feature_Previews: PreviewProvider {
  static var previews: some  View {
    FeatureView(
      store: Store(
        initialState: Feature.State(
          destination: .edit(EditFeature.State())
        )
      ) {
        Feature()
      }
    )
  }
}
```

#### CI build failures

When testing your code on an external CI server you may run into errors such as the following:

> Error: CasePathsMacros Target 'CasePathsMacros' must be enabled before it can be used.
>
> ComposableArchitectureMacros Target 'ComposableArchitectureMacros' must be enabled before it can
> be used.

You can fix this in one of two ways. You can write a default to the CI machine that allows Xcode to
skip macro validation:

```shell
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
```

Or if you are invoking `xcodebuild` directly in your CI scripts, you can pass the
`-skipMacroValidation` flag to `xcodebuild` when building your project:

```shell
xcodebuild -skipMacroValidation …
```

[casepathable-docs]: https://swiftpackageindex.com/pointfreeco/swift-case-paths/main/documentation/casepaths/casepathable()
[casepaths-gh]: http://github.com/pointfreeco/swift-case-paths

## Topics

- ``Reducer()``
