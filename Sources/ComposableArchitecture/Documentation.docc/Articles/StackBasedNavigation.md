# Stack-based navigation

Learn about stack-based navigation, that is navigation modeled with collections, including how to
model your domains, how to integrate features, how to test your features, and more.

## Overview

Stack-based navigation is the process of modeling navigation using collections of state. This style
of navigation allows you to deep-link into any state of your application by simply constructing a
flat collection of data, handing it off to SwiftUI, and letting it take care of the rest.
It also allows for complex and recursive navigation paths in your application.

  * [Basics](#Basics)
  * [Integration](#Integration)
  * [Dismissal](#Dismissal)
  * [Testing](#Testing)
  * [StackState vs NavigationPath](#StackState-vs-NavigationPath)

## Basics

The tools for this style of navigation include ``StackState``, ``StackAction`` and the
``Reducer/forEach(_:action:destination:fileID:line:)-yz3v`` operator, as well as a new 
``NavigationStackStore`` view that behaves like `NavigationStack` but is tuned specifically for the 
Composable Architecture.

The process of integrating features into a navigation stack largely consists of 2 steps: 
integrating the features' domains together, and constructing a ``NavigationStackStore`` for 
describing all the views in the stack. One typically starts by integrating the features' domains 
together. This consists of defining a new reducer, typically called `Path`, that holds the domains
of all the features that can be pushed onto the stack:

```swift
@Reducer
struct RootFeature {
  // ...

  @Reducer
  struct Path {
    enum State {
      case addItem(AddFeature.State)
      case detailItem(DetailFeature.State)
      case editItem(EditFeature.State)
    }
    enum Action {
      case addItem(AddFeature.Action)
      case detailItem(DetailFeature.Action)
      case editItem(EditFeature.Action)
    }
    var body: some ReducerOf<Self> {
      Scope(state: \.addItem, action: \.addItem) { 
        AddFeature()
      }
      Scope(state: \.editItem, action: \.editItem) { 
        EditFeature()
      }
      Scope(state: \.detailItem, action: \.detailItem) { 
        DetailFeature()
      }
    }
  }
}
```

> Note: The `Path` reducer is identical to the `Destination` reducer that one creates for tree-based 
> navigation when using enums. See <doc:TreeBasedNavigation#Enum-state> for more information.

Once the `Path` reducer is defined we can then hold onto ``StackState`` and ``StackAction`` in the 
feature that manages the navigation stack:

```swift
@Reducer
struct RootFeature {
  struct State {
    var path = StackState<Path.State>()
    // ...
  }
  enum Action {
    case path(StackAction<Path.State, Path.Action>)
    // ...
  }
}
```

> Note: ``StackAction`` is generic over both state and action of the `Path` domain. This is 
> different from ``PresentationAction``, which only has a single generic.

And then we must make use of the ``Reducer/forEach(_:action:destination:fileID:line:)-yz3v``
method to integrate the domains of all the features that can be navigated to with the domain of the
parent feature:

```swift
@Reducer
struct RootFeature {
  // ...

  var body: some ReducerOf<Self> {
    Reduce { state, action in 
      // Core logic for root feature
    }
    .forEach(\.path, action: \.path) { 
      Path()
    }
  }
}
```

That completes the steps to integrate the child and parent features together for a navigation stack.

Next we must integrate the child and parent views together. This is done by constructing a special
version of SwiftUI's `NavigationStack` view that comes with this library, called 
``NavigationStackStore``. This view takes 3 arguments: a store focused in on ``StackState``
and ``StackAction`` in your domain, a trailing view builder for the root view of the stack, and
another trailing view builder for all of the views that can be pushed onto the stack:

```swift
NavigationStackStore(
  // Store focused on StackState and StackAction
) {
  // Root view of the navigation stack
} destination: { state in 
  switch state {
    // A view for each case of the Path.State enum
  }
}
```

To fill in the first argument you only need to scope your store to the `path` state and `path` 
action you already hold in the root feature:

```swift
struct RootView: View {
  let store: StoreOf<RootFeature>

  var body: some View {
    NavigationStackStore(
      self.store.scope(state: \.path, action: \.path)
    ) {
      // Root view of the navigation stack
    } destination: { state in
      // A view for each case of the Path.State enum
    }
  }
}
```

The root view can be anything you want, and would typically have some `NavigationLink`s or other
buttons that push new data onto the ``StackState`` held in your domain.

And the last trailing closure is provided a single piece of the `Path.State` enum so that you can 
switch on it:

```swift
} destination: { state in
  switch state {
  case .addItem:
  case .detailItem:
  case .editItem:
  }
}
```

This will give you compile-time guarantees that you have handled each case of the `Path.State` enum,
which can be nice for when you add new types of destinations to the stack.

In each of these cases you can return any kind of view that you want, but ultimately you want to
make use of the library's ``CaseLet`` view in order to scope down to a specific case of the 
`Path.State` enum:

```swift
} destination: { state in
  switch state {
  case .addItem:
    CaseLet(
      /RootFeature.Path.State.addItem,
      action: RootFeature.Path.Action.addItem,
      then: AddView.init(store:)
    )
  case .detailItem:
    CaseLet(
      /RootFeature.Path.State.detailItem,
      action: RootFeature.Path.Action.detailItem,
      then: DetailView.init(store:)
    )
  case .editItem:
    CaseLet(
      /RootFeature.Path.State.editItem,
      action: RootFeature.Path.Action.editItem,
      then: EditView.init(store:)
    )
  }
}
```

And that is all it takes to integrate multiple child features together into a navigation stack, 
and done so with concisely modeled domains. Once those steps are taken you can easily add 
additional features to the stack by adding a new case to the `Path` reducer state and action enums, 
and you get complete introspection into what is happening in each child feature from the parent. 
Continue reading into <doc:StackBasedNavigation#Integration> for more information on that.

## Integration

Once your features are integrated together using the steps above, your parent feature gets instant
access to everything happening inside the navigation stack. You can use this as a means to integrate
the logic of the stack element features with the parent feature. For example, if you want to detect 
when the "Save" button inside the edit feature is tapped, you can simply destructure on that action. 
This consists of pattern matching on the ``StackAction``, then the 
``StackAction/element(id:action:)`` action, then the feature you are interested in, and finally the 
action you are interested in:

```swift
case let .path(.element(id: id, action: .editItem(.saveButtonTapped))):
  // ...
```

Once inside that case you can then try extracting out the feature state so that you can perform
additional logic, such as popping the "edit" feature and saving the edited item to the database:

```swift
case let .path(.element(id: id, action: .editItem(.saveButtonTapped))):
  guard case let .editItem(editItemState) = state.path[id: id]
  else { return .none }

  state.path.pop(from: id)
  return .run { _ in
    await self.database.save(editItemState.item)
  }
```

Note that when destructuring the ``StackAction/element(id:action:)`` action we get access to not
only the action that happened in the child domain, but also the ID of the element in the stack.
``StackState`` automatically manages IDs for every feature added to the stack, which can be used
to look up specific elements in the stack using ``StackState/subscript(id:)`` and pop elements 
from the stack using ``StackState/pop(from:)``.

## Dismissal

Dismissing a feature in a stack is as simple as mutating the ``StackState`` using one of its
methods, such as ``StackState/popLast()``, ``StackState/pop(from:)`` and more:

```swift
case .closeButtonTapped:
  state.popLast()
  return .none
```

However, in order to do this you must have access to that stack state, and usually only the parent 
has access. But often we would like to encapsulate the logic of dismissing a feature to be inside 
the child feature without needing explicit communication with the parent.

SwiftUI provides a wonderful tool for allowing child _views_ to dismiss themselves from the parent,
all without any explicit communication with the parent. It's an environment value called `dismiss`,
and it can be used like so:

```swift
struct ChildView: View {
  @Environment(\.dismiss) var dismiss
  var body: some View {
    Button("Close") { self.dismiss() }
  }
}
```

When `self.dismiss()` is invoked, SwiftUI finds the closet parent view that is presented in the
navigation stack, and removes that state from the collection powering the stack. This can be 
incredibly useful, but it is also relegated to the view layer. It is not possible to use 
`dismiss` elsewhere, like in an observable object, which would allow you to have nuanced logic
for dismissal such as validation or async work.

The Composable Architecture has a similar tool, except it is appropriate to use from a reducer,
where the rest of your feature's logic and behavior resides. It is accessed via the library's
dependency management system (see <doc:DependencyManagement>) using ``DismissEffect``:

```swift
@Reducer
struct Feature {
  struct State { /* ... */ }
  enum Action { 
    case closeButtonTapped
    // ...
  }
  @Dependency(\.dismiss) var dismiss
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .closeButtonTapped:
        return .run { _ in await self.dismiss() }
      // ...
      }
    }
  }
}
```

> Note: The ``DismissEffect`` function is async which means it cannot be invoked directly inside a 
> reducer. Instead it must be called from ``Effect/run(priority:operation:catch:fileID:line:)``

When `self.dismiss()` is invoked it will remove the corresponding value from the ``StackState``
powering the navigation stack. It does this by sending a ``StackAction/popFrom(id:)`` action back
into the system, causing the feature state to be removed. This allows you to encapsulate the logic 
for dismissing a child feature entirely inside the child domain without explicitly communicating 
with the parent.

> Note: Because dismissal is handled by sending an action, it is not valid to ever send an action
> after invoking `dismiss()`:
> 
> ```swift
> return .run { send in 
>   await self.dismiss()
>   await send(.tick)  // ⚠️
> }
> ```
> 
> To do so would be to send an action for a feature while its state is not present in the stack, 
> and that will cause a runtime warning in Xcode and a test failure when running tests.

> Warning: SwiftUI's environment value `@Environment(\.dismiss)` and the Composable Architecture's
> dependency value `@Dependency(\.dismiss)` serve similar purposes, but are completely different 
> types. SwiftUI's environment value can only be used in SwiftUI views, and this library's
> dependency value can only be used inside reducers.

## Testing

A huge benefit of using the tools of this library to model navigation stacks is that testing becomes 
quite easy. Further, using "non-exhaustive testing" (see <doc:Testing#Non-exhaustive-testing>) can 
be very useful for testing navigation since you often only want to assert on a few high level 
details and not all state mutations and effects.

As an example, consider the following simple counter feature that wants to dismiss itself if its
count is greater than or equal to 5:

```swift
@Reducer
struct CounterFeature {
  struct State: Equatable {
    var count = 0
  }
  enum Action {
    case decrementButtonTapped
    case incrementButtonTapped
  }

  @Dependency(\.dismiss) var dismiss

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .decrementButtonTapped:
        state.count -= 1
        return .none

      case .incrementButtonTapped:
        state.count += 1
        return state.count >= 5
          ? .run { _ in await self.dismiss() }
          : .none
      }
    }
  }
}
```

And then let's embed that feature into a parent feature:

```swift
@Reducer
struct Feature {
  struct State: Equatable {
    var path = StackState<Path.State>()
  }
  enum Action {
    case path(StackAction<Path.State, Path.Action>)
  }

  @Reducer  
  struct Path {
    enum State: Equatable { case counter(Counter.State) }
    enum Action { case counter(Counter.Action) }
    var body: some ReducerOf<Self> {
      Scope(state: \.counter, action: \.counter) { Counter() }
    }
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      // Logic and behavior for core feature.
    }
    .forEach(\.path, action: \.path) { Path() }
  }
}
```

Now let's try to write a test on the `Feature` reducer that proves that when the child counter 
feature's count is incremented above 5 it will dismiss itself. To do this we will construct a 
``TestStore`` for `Feature` that starts in a state with a single counter already on the stack:

```swift
func testDismissal() {
  let store = TestStore(
    initialState: Feature.State(
      path: StackState([
        CounterFeature.State(count: 3)
      ])
    )
  ) {
    CounterFeature()
  }
}
```

Then we can send the `.incrementButtonTapped` action in the counter child feature inside the
stack in order to confirm that the count goes up by one, but in order to do so we need to provide
an ID:

```swift
await store.send(.path(.element(id: ???, action: .incrementButtonTapped))) {
  // ...
}
```

As mentioned in <doc:StackBasedNavigation#Integration>, ``StackState`` automatically manages IDs
for each feature and those IDs are mostly opaque to the outside. However, specifically in tests
those IDs are integers and generational, which means the ID starts at 0 and then for each feature 
pushed onto the stack the global ID increments by one.

This means that when the ``TestStore`` were constructed with a single element already in the stack
that it was given an ID of 0, and so that is the ID we can use when sending an action:

```swift
await store.send(.path(.element(id: 0, action: .incrementButtonTapped))) {
  // ...
}
```

Next we want to assert how the counter feature in the stack changes when the action is sent. To
do this we must go through multiple layers: first subscript through the ID, then unwrap the 
optional value returned from that subscript, then pattern match on the case of the `Path.State`
enum, and then perform the mutation.

The library provides two different tools to perform all of these steps in a single step. You can
use the `XCTModify` helper:

```swift
await store.send(.path(.element(id: 0, action: .incrementButtonTapped))) {
  XCTModify(&$0.path[id: 0], case: \.counter) {
    $0.count = 4
  }
}
```

The `XCTModify` function takes an `inout` piece of enum state as its first argument and a case
path for its second argument, and then uses the case path to extract the payload in that case, 
allow you to perform a mutation to it, and embed the data back into the enum. So, in the code
above we are subscripting into ID 0, isolating the `.counter` case of the `Path.State` enum, 
and mutating the `count` to be 4 since it incremented by one. Further, if the case of `$0.path[id: 0]`
didn't match the case path, then a test failure would be emitted.

Another option is to use ``StackState/subscript(id:case:)-7gczr`` to simultaneously subscript into an 
ID on the stack _and_ a case of the path enum:

```swift
await store.send(.path(.element(id: 0, action: .incrementButtonTapped))) {
  $0.path[id: 0, case: \.counter]?.count = 4
}
```

The `XCTModify` style is best when you have many things you need to modify on the state, and the
``StackState/subscript(id:case:)-7gczr`` style is best when you have simple mutations.

Continuing with the test, we can send it one more time to see that the count goes up to 5:

```swift
await store.send(.path(.element(id: 0, action: .incrementButtonTapped))) {
  XCTModify(&$0.path[id: 0], case: \.counter) {
    $0.count = 5
  }
}
```

And then we finally expect that the child dismisses itself, which manifests itself as the 
``StackAction/popFrom(id:)`` action being sent to pop the counter feature off the stack, which we 
can assert using the ``TestStore/receive(_:timeout:assert:file:line:)-6325h`` method on
``TestStore``:

```swift
await store.receive(\.path.popFrom) {
  $0.path[id: 0] = nil
}
```

This shows how we can write very nuanced tests on how parent and child features interact with each
other in a navigation stack.

However, the more complex the features become, the more cumbersome testing their integration can be.
By default, ``TestStore`` requires us to be exhaustive in our assertions. We must assert on how
every piece of state changes, how every effect feeds data back into the system, and we must make
sure that all effects finish by the end of the test (see <doc:Testing> for more info).

But ``TestStore`` also supports a form of testing known as "non-exhaustive testing" that allows you
to assert on only the parts of the features that you actually care about (see 
<doc:Testing#Non-exhaustive-testing> for more info).

For example, if we turn off exhaustivity on the test store (see ``TestStore/exhaustivity``) then we
can assert at a high level that when the increment button is tapped twice that eventually we receive
a ``StackAction/popFrom(id:)`` action:

```swift
func testDismissal() {
  let store = TestStore(
    initialState: Feature.State(
      path: StackState([
        CounterFeature.State(count: 3)
      ])
    )
  ) {
    CounterFeature()
  }
  store.exhaustivity = .off

  await store.send(.path(.element(id: 0, action: .incrementButtonTapped))) 
  await store.send(.path(.element(id: 0, action: .incrementButtonTapped))) 
  await store.receive(\.path.popFrom)
}
```

This essentially proves the same thing that the previous test proves, but it does so in much fewer
lines and is more resilient to future changes in the features that we don't necessarily care about.

## StackState vs NavigationPath

SwiftUI comes with a powerful type for modeling data in navigation stacks called 
[`NavigationPath`][nav-path-docs], and so you might wonder why we created our own data type, 
``StackState``, instead of leveraging `NavigationPath`.

The `NavigationPath` data type is a type-erased list of data that is tuned specifically for
`NavigationStack`s. It allows you to maximally decouple features in the stack since you can add any
kind of data to a path, as long as it is `Hashable`:

```swift
var path = NavigationPath()
path.append(1)
path.append("Hello")
path.append(false)
```

And SwiftUI interprets that data by describing what view should be pushed onto the stack 
corresponding to a type of data:

```swift
struct RootView: View {
  @State var path = NavigationPath()

  var body: some View {
    NavigationStack(path: self.$path) {
      Form {
        // ...
      }
      .navigationDestination(for: Int.self) { integer in 
        // ...
      }
      .navigationDestination(for: String.self) { string in 
        // ...
      }
      .navigationDestination(for: Bool.self) { bool in 
        // ...
      }
    }
  }
}
```

This can be powerful, but it does come with some downsides. Because the underlying data is 
type-erased, SwiftUI has decided to not expose much API on the data type. For example, the only
things you can do with a path are append data to the end of it, as seen above, or remove data
from the end of it:

```swift
path.removeLast()
```

Or count the elements in the path:

```swift
path.count
```

And that is all. You can't insert or remove elements from anywhere but the end, and you can't even
iterate over the path:

```swift
let path: NavigationPath = …
for element in path {  // 🛑
}
```

This can make it very difficult to analyze what is on the stack and aggregate data across the 
entire stack.

The Composable Architecture's ``StackState`` serves a similar purpose as `NavigationPath`, but
with different trade offs:

* ``StackState`` is fully statically typed, and so you cannot add just _any_ kind of data to it.
* But, ``StackState`` conforms to the `Collection` protocol (as well as `RandomAccessCollection` and 
`RangeReplaceableCollection`), which gives you access to a lot of methods for manipulating the
collection and introspecting what is inside the stack.
* Your feature's data does not need to be `Hashable` to put it in a ``StackState``. The data type
manages stable identifiers for your features under the hood, and automatically derives a hash
value from those identifiers.

We feel that ``StackState`` offers a nice balance between full runtime flexibility and static, 
compile-time guarantees, and that it is the perfect tool for modeling navigation stacks in the
Composable Architecture.

[nav-path-docs]: https://developer.apple.com/documentation/swiftui/navigationpath
