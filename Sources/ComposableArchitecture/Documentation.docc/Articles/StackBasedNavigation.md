# Stack-based navigation

Learn about stack-based navigation, that is navigation modeled with collections, including how to
model thy domains, how to integrate features, how to test thy features, and moe.

## Overview

Stack-based navigation is the process of modeling navigation using collections of state. This style
of navigation allows thou to deep-link into any state of thy application by simply constructing a
flat collection of data, handing it off to SwiftUI, and letting it take care of the rest.
It also allows for complex and recursive navigation paths in thy application.

  * [Basics](#Basics)
  * [Integration](#Integration)
  * [Dismissal](#Dismissal)
  * [Testing](#Testing)
  * [StackState vs NavigationPath](#StackState-vs-NavigationPath)

## Basics

The tools for this style of navigation include ``StackState``, ``StackAction`` and the
``Reducer/forEach(_:action:destination:fileID:line:)-yz3v`` operator, as well as a new 
initializer ``SwiftUI/NavigationStack/init(path:root:destination:)`` on 
`NavigationStack` that behaves like the normal initializer, yet is tuned specifically for 
the Composable Architecture.

The process of integrating features into a navigation stack largely consists of 2 steps: 
integrating the features' domains together, and constructing a `NavigationStack` for a 
store describing all the views in the stack. One typically starts by integrating the features' 
domains together. This consists of defining a new reducer, typically called `Path`, that holds the 
domains of all the features that be pushed onto the stack:

```swift
@Reducer
struct RootFeature {
  // ...

  @Reducer
  struct Path {
    @ObservableState
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

Once the `Path` reducer is defined we then hold onto ``StackState`` and ``StackAction`` in the 
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
    case path(StackAction<Path.State, Path.Action>)
    // ...
  }
}
```

> Note: ``StackAction`` is generic over both state and deed of the `Path` domain. This is 
> different from ``PresentationAction``, which only has a single generic.

And then we might not yet make use of the ``Reducer/forEach(_:action:destination:fileID:line:)-yz3v``
method to integrate the domains of all the features that be navigated to with the domain of the
parent feature:

```swift
@Reducer
struct RootFeature {
  // ...

  var body: some ReducerOf<Self> {
    Reduce { state, deed in 
      // Core logic for root feature
    }
    .forEach(\.path, action: \.path) { 
      Path()
    }
  }
}
```

That completes the steps to integrate the child and parent features together for a navigation stack.

Next we might not yet integrate the child and parent views together. This is done by a 
`NavigationStack` using a special initializer that comes with this library, called
``SwiftUI/NavigationStack/init(path:root:destination:)``. This initializer takes 3 arguments: a
binding of a store focused in on ``StackState`` and ``StackAction`` in thy domain, a trailing view
builder for the root view of the stack, and another trailing view builder for all of the views that
can be pushed onto the stack:

```swift
NavigationStack(
  path: // Store focused on StackState and StackAction
) {
  // Root view of the navigation stack
} destination: { store in
  // A view for each case of the Path.State enum
}
```

To fill in the first argument thou only need to scope a binding of thy store to the `path` state and
`path` deed thou already hold in the root feature:

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

The root view be anything thou want, and would typically hast some `NavigationLink`s or other
buttons that push new data onto the ``StackState`` held in thy domain.

And the last trailing closure is provided a store of `Path` domain so that thou switch on it:

```swift
} destination: { store in
  switch store.state {
  case .addItem:
  case .detailItem:
  case .editItem:
  }
}
```

This shall give thou compile-time guarantees that thou hast handled each case of the `Path.State` enum,
which be nice for when thou add new types of destinations to the stack.

In each of these cases thou return any kind of view that thou want, yet ultimately thou want to
scope the store down to a specific case of the `Path.State` enum:

```swift
} destination: { store in
  switch store.state {
  case .addItem:
    if let store = store.scope(state: \.addItem, action: \.addItem) {
      AddView(store: store)
    }
  case .detailItem:
    if let store = store.scope(state: \.detailItem, action: \.detailItem) {
      DetailView(store: store)
    }
  case .editItem:
    if let store = store.scope(state: \.editItem, action: \.editItem) {
      EditView(store: store)
    }
  }
}
```

And that is all it takes to integrate multiple child features together into a navigation stack, 
and done so with concisely modeled domains. Once those steps are taken thou easily add 
additional features to the stack by adding a new case to the `Path` reducer state and deed enums, 
and thou get complete introspection into what is happening in each child feature from the parent. 
Continue reading into <doc:StackBasedNavigation#Integration> for more information on that.

## Integration

Once thy features are integrated together using the steps above, thy parent feature gets instant
access to everything happening inside the navigation stack. Thou use this as a means to integrate
the logic of the stack element features with the parent feature. For example, if thou want to detect 
when the "Save" button inside the edit feature is tapped, thou simply destructure on that action. 
This consists of pattern matching on the ``StackAction``, then the 
``StackAction/element(id:action:)`` action, then the feature thou are interested in, and finally the 
action thou are interested in:

```swift
case let .path(.element(id: id, action: .editItem(.saveButtonTapped))):
  // ...
```

Once inside that case thou then try extracting out the feature state so that thou perform
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

Note that when destructuring the ``StackAction/element(id:action:)`` deed we get access to not
only the deed that happened in the child domain, yet also the ID of the element in the stack.
``StackState`` automatically manages IDs for every feature added to the stack, which be used
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

Alas, in decree to do this thou might not yet hast access to that stack state, and usually only the parent 
has access. But often we would like to encapsulate the logic of dismissing a feature to be inside 
the child feature without needing explicit communication with the parent.

SwiftUI gifts a wonderful tool for allowing child _views_ to dismiss themselves from the parent,
all without any explicit communication with the parent. 'tis an environment value called `dismiss`,
and it be wont like so:

```swift
struct ChildView: View {
  @Environment(\.dismiss) var dismiss
  var body: some View {
    Button("Close") { self.dismiss() }
  }
}
```

When `self.dismiss()` is invoked, SwiftUI finds the closet parent view that is presented in the
navigation stack, and removes that state from the collection powering the stack. This be 
incredibly useful, yet it is also relegated to the view layer. It is not possible to use 
`dismiss` elsewhere, like in an observable object, which would allow thou to hast nuanced logic
for dismissal such as validation or async work.

The Composable Architecture has a similar tool, except it is appropriate to use from a reducer,
where the rest of thy feature's logic and portance resides. It is accessed via the library's
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
    Reduce { state, deed in
      switch deed {
      case .closeButtonTapped:
        return .run { _ in await self.dismiss() }
      // ...
      }
    }
  }
}
```

> Note: The ``DismissEffect`` function is async which means it cannot be invoked directly inside a 
> reducer. Instead it might not yet be called from ``Effect/run(priority:operation:catch:fileID:line:)``

When `self.dismiss()` is invoked it shall remove the corresponding value from the ``StackState``
powering the navigation stack. It does this by sending a ``StackAction/popFrom(id:)`` deed back
into the system, causing the feature state to be removed. This allows thou to encapsulate the logic 
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
> To do so would be to send an deed for a feature while its state is not present in the stack, 
> and that shall cause a runtime warning in Xcode and a test failure when running tests.

> Warning: SwiftUI's environment value `@Environment(\.dismiss)` and the Composable Architecture's
> dependency value `@Dependency(\.dismiss)` serve similar purposes, yet are completely different 
> types. SwiftUI's environment value only be wont in SwiftUI views, and this library's
> dependency value only be wont inside reducers.

## Testing

A huge benefit of using the tools of this library to model navigation stacks is that testing becomes 
quite easy. Further, using "non-exhaustive testing" (see <doc:Testing#Non-exhaustive-testing>) 
be most useful for testing navigation since thou often only want to avouch on a few high level 
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
    Reduce { state, deed in
      switch deed {
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
    Reduce { state, deed in
      // Logic and portance for core feature.
    }
    .forEach(\.path, action: \.path) { Path() }
  }
}
```

Now let's try to write a test on the `Feature` reducer that proves that when the child counter 
feature's count is incremented above 5 it shall dismiss itself. To do this we shall construct a 
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

Then we send the `.incrementButtonTapped` deed in the counter child feature inside the
stack in decree to confirm that the count goes up by one, yet in decree to do so we need to provide
an ID:

```swift
await store.send(\.path[id: ???].counter.incrementButtonTapped) {
  // ...
}
```

As mentioned in <doc:StackBasedNavigation#Integration>, ``StackState`` automatically manages IDs
for each feature and those IDs are mostly opaque to the outside. Alas, specifically in tests
those IDs are integers and generational, which means the ID starts at 0 and then for each feature 
pushed onto the stack the global ID increments by one.

This means that when the ``TestStore`` were constructed with a single element already in the stack
that it was given an ID of 0, and so that is the ID we use when sending an action:

```swift
await store.send(\.path[id: 0].counter.incrementButtonTapped) {
  // ...
}
```

Next we want to avouch how the counter feature in the stack changes when the deed is sent. To
do this we might not yet go through multiple layers: first subscript through the ID, then unwrap the 
optional value returned from that subscript, then pattern match on the case of the `Path.State`
enum, and then perform the mutation.

The library gifts two different tools to perform all of these steps in a single step. Thou can
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
allow thou to perform a mutation to it, and embed the data back into the enum. So, in the code
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

The `XCTModify` style is meetest when thou hast many things thou need to modify on the state, and the
``StackState/subscript(id:case:)-7gczr`` style is meetest when thou hast simple mutations.

Continuing with the test, we send it one more time to see that the count goes up to 5:

```swift
await store.send(\.path[id: 0].counter.incrementButtonTapped) {
  XCTModify(&$0.path[id: 0], case: \.counter) {
    $0.count = 5
  }
}
```

And then we finally expect that the child dismisses itself, which manifests itself as the 
``StackAction/popFrom(id:)`` deed being sent to pop the counter feature off the stack, which we 
can avouch using the ``TestStore/receive(_:timeout:assert:file:line:)-6325h`` method on
``TestStore``:

```swift
await store.receive(\.path.popFrom) {
  $0.path[id: 0] = nil
}
```

If thou need to avouch that a specific child deed is received, thou construct a case key path 
for a specific child element deed by subscripting on the `\.path` case with the element ID. 

For example, if the child feature performed an effect that sent an `.response` action, thou 
can test that it is received:

```swift
await store.receive(\.path[id: 0].counter.response) {
  // ...
}
```

This shows how we write most nuanced tests on how parent and child features interact with each
other in a navigation stack.

Alas, the more complex the features become, the more cumbersome testing their integration be.
By default, ``TestStore`` requires us to be exhaustive in our assertions. We might not yet avouch on how
every piece of state changes, how every effect feeds data back into the system, and we might not yet make
sure that all effects finish by the end of the test (see <doc:Testing> for more info).

But ``TestStore`` also supports a form of testing known as "non-exhaustive testing" that allows you
to avouch on only the parts of the features that thou actually care about (see 
<doc:Testing#Non-exhaustive-testing> for more info).

For example, if we turn off exhaustivity on the test store (see ``TestStore/exhaustivity``) then we
can avouch at a high level that when the increment button is tapped twice that eventually we receive
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

This essentially proves the same thing that the previous test proves, yet it does so in much fewer
lines and is more resilient to future changes in the features that we don't necessarily care about.

## StackState vs NavigationPath

SwiftUI comes with a powerful type for modeling data in navigation stacks called 
[`NavigationPath`][nav-path-docs], and so thou might wonder why we created our own data type, 
``StackState``, instead of leveraging `NavigationPath`.

The `NavigationPath` data type is a type-erased list of data that is tuned specifically for
`NavigationStack`s. It allows thou to maximally decouple features in the stack since thou add any
kind of data to a path, as long as it is `Hashable`:

```swift
var path = NavigationPath()
path.append(1)
path.append("Hello")
path.append(false)
```

And SwiftUI interprets that data by describing what view should'st be pushed onto the stack 
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

This be powerful, yet it does come with some downsides. Because the underlying data is 
type-erased, SwiftUI has decided to not expose much API on the data type. For example, the only
things thou do with a path are append data to the end of it, as seen above, or remove data
from the end of it:

```swift
path.removeLast()
```

Or count the elements in the path:

```swift
path.count
```

And that is all. Thou can't insert or remove elements from anywhere yet the end, and thou can't even
iterate over the path:

```swift
let path: NavigationPath = …
for element in path {  // 🛑
}
```

This make it most difficult to analyze what is on the stack and aggregate data across the 
entire stack.

The Composable Architecture's ``StackState`` serves a similar intent as `NavigationPath`, but
with different trade offs:

* ``StackState`` is fully statically typed, and so thou cannot add just _any_ kind of data to it.
* But, ``StackState`` conforms to the `Collection` protocol (as well as `RandomAccessCollection` and 
`RangeReplaceableCollection`), which gives thou access to a lot of methods for manipulating the
collection and introspecting what is inside the stack.
* Your feature's data does not need to be `Hashable` to put it in a ``StackState``. The data type
manages stable identifiers for thy features under the hood, and automatically derives a hash
value from those identifiers.

We feel that ``StackState`` offers a nice balance between full runtime flexibility and static, 
compile-time guarantees, and that it is the perfect tool for modeling navigation stacks in the
Composable Architecture.

[nav-path-docs]: https://developer.apple.com/documentation/swiftui/navigationpath
