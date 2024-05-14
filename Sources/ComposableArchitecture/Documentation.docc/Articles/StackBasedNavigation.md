# Stack-based navigation

Learn about stack-based navigation, that is navigation modeled with collections, including how to
model your domains, how to integrate features, how to test your features, and more.

## Overview

Stack-based navigation is the process of modeling navigation using collections of state. This style
of navigation allows you to deep-link into any state of your application by simply constructing a
flat collection of data, handing it off to SwiftUI, and letting it take care of the rest.
It also allows for complex and recursive navigation paths in your application.

  * [Basics](#Basics)
  * [Pushing features onto the stack](#Pushing-features-onto-the-stack)
  * [Integration](#Integration)
  * [Dismissal](#Dismissal)
  * [Testing](#Testing)
  * [StackState vs NavigationPath](#StackState-vs-NavigationPath)

## Basics

The tools for this style of navigation include ``StackState``, ``StackAction`` and the
``Reducer/forEach(_:action:destination:fileID:line:)-yz3v`` operator, as well as a new 
initializer ``SwiftUI/NavigationStack/init(path:root:destination:fileID:line:)`` on 
`NavigationStack` that behaves like the normal initializer, but is tuned specifically for 
the Composable Architecture.

The process of integrating features into a navigation stack largely consists of 2 steps: 
integrating the features' domains together, and constructing a `NavigationStack` for a 
store describing all the views in the stack. One typically starts by integrating the features' 
domains together. This consists of defining a new reducer, typically called `Path`, that holds the 
domains of all the features that can be pushed onto the stack:

```swift
@Reducer
struct RootFeature {
  // ...

  @Reducer
  enum Path {
    case addItem(AddFeature)
    case detailItem(DetailFeature)
    case editItem(EditFeature)
  }
}
```

> Note: The `Path` reducer is identical to the `Destination` reducer that one creates for 
> tree-based navigation when using enums. See <doc:TreeBasedNavigation#Enum-state> for more
> information.

Once the `Path` reducer is defined we can then hold onto ``StackState`` and ``StackAction`` in the 
feature that manages the navigation stack:

```swift
@Reducer
struct RootFeature {
  @ObservableState
  struct State {
    var path = StackState<Path.State>()
    // ...
  }
  enum Action {
    case path(StackActionOf<Path>)
    // ...
  }
}
```

> Tip: ``StackAction`` is generic over both state and action of the `Path` domain, and so you can
> use the ``StackActionOf`` typealias to simplify the syntax a bit. This is different from
> ``PresentationAction``, which only has a single generic of `Action`.

And then we must make use of the ``Reducer/forEach(_:action:)`` method to integrate the domains of
all the features that can be navigated to with the domain of the parent feature:

```swift
@Reducer
struct RootFeature {
  // ...

  var body: some ReducerOf<Self> {
    Reduce { state, action in 
      // Core logic for root feature
    }
    .forEach(\.path, action: \.path)
  }
}
```

> Note: You do not need to specify `Path()` in a trailing closure of `forEach` because it can be
> automatically inferred from `@Reducer enum Path`.

That completes the steps to integrate the child and parent features together for a navigation stack.

Next we must integrate the child and parent views together. This is done by a 
`NavigationStack` using a special initializer that comes with this library, called
``SwiftUI/NavigationStack/init(path:root:destination:fileID:line:)``. This initializer takes 3 
arguments: a binding of a store focused in on ``StackState`` and ``StackAction`` in your domain, a 
trailing view builder for the root view of the stack, and another trailing view builder for all of 
the views that can be pushed onto the stack:

```swift
NavigationStack(
  path: // Store focused on StackState and StackAction
) {
  // Root view of the navigation stack
} destination: { store in
  // A view for each case of the Path.State enum
}
```

To fill in the first argument you only need to scope a binding of your store to the `path` state and
`path` action you already hold in the root feature:

```swift
struct RootView: View {
  @Bindable var store: StoreOf<RootFeature>

  var body: some View {
    NavigationStack(
      path: $store.scope(state: \.path, action: \.path)
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

And the last trailing closure is provided a store of `Path` domain, and you can use the 
``Store/case`` computed property to destructure each case of the `Path` to obtain a store focused
on just that case:

```swift
} destination: { store in
  switch store.case {
  case .addItem(let store):
  case .detailItem(let store):
  case .editItem(let store):
  }
}
```

This will give you compile-time guarantees that you have handled each case of the `Path.State` enum,
which can be nice for when you add new types of destinations to the stack.

In each of these cases you can return any kind of view that you want, but ultimately you want to
scope the store down to a specific case of the `Path.State` enum:

```swift
} destination: { store in
  switch store.case {
  case .addItem(let store):
    AddView(store: store)
  case .detailItem(let store):
    DetailView(store: store)
  case .editItem(let store):
    EditView(store: store)
  }
}
```

And that is all it takes to integrate multiple child features together into a navigation stack, 
and done so with concisely modeled domains. Once those steps are taken you can easily add 
additional features to the stack by adding a new case to the `Path` reducer state and action enums, 
and you get complete introspection into what is happening in each child feature from the parent. 
Continue reading into <doc:StackBasedNavigation#Integration> for more information on that.

## Pushing features onto the stack

There are two primary ways to push features onto the stack once you have their domains integrated
and `NavigationStack` in the view, as described above. The simplest way is to use the 
``SwiftUI/NavigationLink/init(state:label:fileID:line:)`` initializer on `NavigationLink`, which
requires you to specify the state of the feature you want to push onto the stack. You must specify
the full state, going all the way back to the `Path` reducer's state:

```swift
Form {
  NavigationLink(
    state: RootFeature.Path.State.detail(DetailFeature.State())
  ) {
    Text("Detail")
  }
}
```

When the link is tapped a ``StackAction/push(id:state:)`` action will be sent, causing the `path`
collection to be mutated and appending the `.detail` state to the stack.

This is by far the simplest way to navigate to a screen, but it also has its drawbacks. In 
particular, it makes modularity difficult since the view that holds onto the `NavigationLink` must
have access to the `Path.State` type, which means it needs to build all of the `Path` reducer, 
including _every_ feature that can be navigated to.

This hurts modularity because it is no longer possible to build each feature that can be presented
in the stack individually, in full isolation. You must build them all together. Technically you can
move all features' `State` types (and only the `State` types) to a separate module, and then
features can depend on only that module without needing to build every feature's reducer.

Another alternative is to forgo `NavigationLink` entirely and just use `Button` that sends an action
in the child feature's domain:

```swift
Form {
  Button("Detail") {
    store.send(.detailButtonTapped)
  }
}
```

Then the root feature can listen for that action and append to the `path` with new state in order
to drive navigation:

```swift
case .path(.element(id: _, action: .list(.detailButtonTapped))):
  state.path.append(.detail(DetailFeature.State()))
  return .none
```

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
  guard let editItemState = state.path[id: id]?.editItem
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

When `self.dismiss()` is invoked, SwiftUI finds the closest parent view that is presented in the
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
  @ObservableState
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
  @ObservableState
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
  @ObservableState
  struct State: Equatable {
    var path = StackState<Path.State>()
  }
  enum Action {
    case path(StackActionOf<Path>)
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
await store.send(\.path[id: ???].counter.incrementButtonTapped) {
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
await store.send(\.path[id: 0].counter.incrementButtonTapped) {
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
await store.send(\.path[id: 0].counter.incrementButtonTapped) {
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
await store.send(\.path[id: 0].counter.incrementButtonTapped) {
  $0.path[id: 0, case: \.counter]?.count = 4
}
```

The `XCTModify` style is best when you have many things you need to modify on the state, and the
``StackState/subscript(id:case:)-7gczr`` style is best when you have simple mutations.

Continuing with the test, we can send it one more time to see that the count goes up to 5:

```swift
await store.send(\.path[id: 0].counter.incrementButtonTapped) {
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

If you need to assert that a specific child action is received, you can construct a case key path 
for a specific child element action by subscripting on the `\.path` case with the element ID. 

For example, if the child feature performed an effect that sent an `.response` action, you 
can test that it is received:

```swift
await store.receive(\.path[id: 0].counter.response) {
  // ...
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

  await store.send(\.path[id: 0].counter.incrementButtonTapped)
  await store.send(\.path[id: 0].counter.incrementButtonTapped)
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
