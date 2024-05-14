# Tree-based navigation

Learn about tree-based navigation, that is navigation modeled with optionals and enums, including
how to model your domains, how to integrate features, how to test your features, and more.

## Overview

Tree-based navigation is the process of modeling navigation using optional and enum state. This 
style of navigation allows you to deep-link into any state of your application by simply 
constructing a deeply nested piece of state, handing it off to SwiftUI, and letting it take care of
the rest.

  * [Basics](#Basics)
  * [Enum state](#Enum-state)
  * [Integration](#Integration)
  * [Dismissal](#Dismissal)
  * [Testing](#Testing)

## Basics

The tools for this style of navigation include the ``Presents()`` macro,
``PresentationAction``, the ``Reducer/ifLet(_:action:destination:fileID:line:)-4f2at`` operator, 
and that is all. Once your feature is properly integrated with those tools you can use all of 
SwiftUI's normal navigation view modifiers, such as `sheet(item:)`, `popover(item:)`, etc.

The process of integrating two features together for navigation largely consists of 2 steps:
integrating the features' domains together and integrating the features' views together. One
typically starts by integrating the features' domains together. This consists of adding the child's
state and actions to the parent, and then utilizing a reducer operator to compose the child reducer
into the parent.

For example, suppose you have a list of items and you want to be able to show a sheet to display a
form for adding a new item. We can integrate state and actions together by utilizing the 
``Presents()`` macro and ``PresentationAction`` type:

```swift
@Reducer
struct InventoryFeature {
  @ObservableState
  struct State: Equatable {
    @Presents var addItem: ItemFormFeature.State?
    var items: IdentifiedArrayOf<Item> = []
    // ...
  }

  enum Action {
    case addItem(PresentationAction<ItemFormFeature.Action>)
    // ...
  }

  // ...
}
``` 

> Note: The `addItem` state is held as an optional. A non-`nil` value represents that feature is
> being presented, and `nil` presents the feature is dismissed.

Next you can integrate the reducers of the parent and child features by using the 
``Reducer/ifLet(_:action:destination:fileID:line:)-4f2at`` reducer operator, as well as having an 
action in the parent domain for populating the child's state to drive navigation:

```swift
@Reducer
struct InventoryFeature {
  @ObservableState
  struct State: Equatable { /* ... */ }
  enum Action { /* ... */ }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in 
      switch action {
      case .addButtonTapped:
        // Populating this state performs the navigation
        state.addItem = ItemFormFeature.State()
        return .none

      // ...
      }
    }
    .ifLet(\.$addItem, action: \.addItem) {
      ItemFormFeature()
    }
  }
}
```

> Note: The key path used with `ifLet` focuses on the `@PresentationState` projected value since it 
> uses the `$` syntax. Also note that the action uses a
> [case path](http://github.com/pointfreeco/swift-case-paths), which is analogous to key paths but
> tuned for enums.

That's all that it takes to integrate the domains and logic of the parent and child features. Next
we need to integrate the features' views. This is done by passing a binding of a store to one
of SwiftUI's view modifiers.

For example, to show a sheet from the `addItem` state in the `InventoryFeature`, we can hand
the `sheet(item:)` modifier a binding of a ``Store`` as an argument that is focused on presentation
state and actions:

```swift
struct InventoryView: View {
  @Bindable var store: StoreOf<InventoryFeature>

  var body: some View {
    List {
      // ...
    }
    .sheet(
      item: $store.scope(state: \.addItem, action: \.addItem)
    ) { store in
      ItemFormView(store: store)
    }
  }
}
```

> Note: We use SwiftUI's `@Bindable` property wrapper to produce a binding to a store, which can be
> further scoped using ``SwiftUI/Binding/scope(state:action:fileID:line:)``.

With those few steps completed the domains and views of the parent and child features are now
integrated together, and when the `addItem` state flips to a non-`nil` value the sheet will be
presented, and when it is `nil`'d out it will be dismissed.

In this example we are using the `.sheet` view modifier, but every view modifier SwiftUI ships can
be handed a store in this fashion, including `popover(item:)`, `fullScreenCover(item:),
`navigationDestination(item:)`, and more. This should make it possible to use optional state to
drive any kind of navigation in a SwiftUI application.

## Enum state

While driving navigation with optional state can be powerful, it can also lead to less-than-ideal
modeled domains. In particular, if a feature can navigate to multiple screens then you may be 
tempted to model that with multiple optional values:

```swift
@ObservableState
struct State {
  @Presents var detailItem: DetailFeature.State?
  @Presents var editItem: EditFeature.State?
  @Presents var addItem: AddFeature.State?
  // ...
}
```

However, this can lead to invalid states, such as 2 or more states being non-nil at the same time,
and that can cause a lot of problems. First of all, SwiftUI does not support presenting multiple 
views at the same time from a single view, and so by allowing this in our state we run the risk of 
putting our application into an inconsistent state with respect to SwiftUI.

Second, it becomes more difficult for us to determine what feature is actually being presented. We
must check multiple optionals to figure out which one is non-`nil`, and then we must figure out how
to interpret when multiple pieces of state are non-`nil` at the same time.

And the number of invalid states increases exponentially with respect to the number of features that
can be navigated to. For example, 3 optionals leads to 4 invalid states, 4 optionals leads to 11
invalid states, and 5 optionals leads to 26 invalid states.

For these reasons, and more, it can be better to model multiple destinations in a feature as a
single enum rather than multiple optionals. So the example of above, with 3 optionals, can be
refactored as an enum:

```swift
enum State {
  case addItem(AddFeature.State)
  case detailItem(DetailFeature.State)
  case editItem(EditFeature.State)
  // ...
}
```

This gives us compile-time proof that only one single destination can be active at a time.

In order to utilize this style of domain modeling you must take a few extra steps. First you model a
"destination" reducer that encapsulates the domains and behavior of all of the features that you can
navigate to. Typically it's best to nest this reducer inside the feature that can perform the
navigation, and the ``Reducer()`` macro can do most of the heavy lifting for us by implementing the
entire reducer from a simple description of the features that can be navigated to:

```swift
@Reducer
struct InventoryFeature {
  // ...

  @Reducer
  enum Destination {
    case addItem(AddFeature)
    case detailItem(DetailFeature)
    case editItem(EditFeature)
  }
}
```

> Note: The ``Reducer()`` macro takes this simple enum description of destination features and
> expands it into a fully composed feature that operates on enum state with a case for each
> feature's state. You can expand the macro code in Xcode to see everything that is written for you.

With that done we can now hold onto a _single_ piece of optional state in our feature, using the
``Presents()`` macro, and we hold onto the destination actions using the
``PresentationAction`` type:

```swift
@Reducer
struct InventoryFeature {
  @ObservableState
  struct State { 
    @Presents var destination: Destination.State?
    // ...
  }
  enum Action {
    case destination(PresentationAction<Destination.Action>)
    // ...
  }

  // ...
}
```

And then we must make use of the ``Reducer/ifLet(_:action:destination:fileID:line:)-8qzye`` operator
to integrate the domain of the destination with the domain of the parent feature:

```swift
@Reducer
struct InventoryFeature {
  // ...

  var body: some ReducerOf<Self> {
    Reduce { state, action in 
      // ...
    }
    .ifLet(\.$destination, action: \.destination) 
  }
}
```

> Note: It's not necessary to specify `Destination` in a trialing closure of `ifLet` because it can
> automatically be inferred due to how the `Destination` enum was defined with the ``Reducer()``
> macro.

That completes the steps for integrating the child and parent features together.

Now when we want to present a particular feature we can simply populate the `destination` state
with a case of the enum:

```swift
case addButtonTapped:
  state.destination = .addItem(AddFeature.State())
  return .none
```

And at any time we can figure out exactly what feature is being presented by switching or otherwise
destructuring the single piece of `destination` state rather than checking multiple optional values.

The final step is to make use of the library's scoping powers to focus in on the `Destination`
domain and further isolate a particular case of the state and action enums via dot-chaining.

For example, suppose the "add" screen is presented as a sheet, the "edit" screen is presented 
by a popover, and the "detail" screen is presented in a drill-down. Then we can use the 
`.sheet(item:)`, `.popover(item:)`, and `.navigationDestination(item:)` view modifiers that come
from SwiftUI to have each of those styles of presentation powered by the respective case of the
destination enum.

To do this you must first hold onto the store in a bindable manner by using the `@Bindable` property
wrapper:

```swift
struct InventoryView: View {
  @Bindable var store: StoreOf<InventoryFeature>
  // ...
}
```

And then in the `body` of the view you can use the
``SwiftUI/Binding/scope(state:action:fileID:line:)`` operator to derive bindings from `$store`:

```swift
var body: some View {
  List {
    // ...
  }
  .sheet(
    item: $store.scope(
      state: \.destination?.addItem,
      action: \.destination.addItem
    )
  ) { store in 
    AddFeatureView(store: store)
  }
  .popover(
    item: $store.scope(
      state: \.destination?.editItem,
      action: \.destination.editItem
    )
  ) { store in 
    EditFeatureView(store: store)
  }
  .navigationDestination(
    item: $store.scope(
      state: \.destination?.detailItem,
      action: \.destination.detailItem
    )
  ) { store in 
    DetailFeatureView(store: store)
  }
}
```

With those steps completed you can be sure that your domains are modeled as concisely as possible.
If the "add" item sheet was presented, and you decided to mutate the `destination` state to point
to the `.detailItem` case, then you can be certain that the sheet will be dismissed and the 
drill-down will occur immediately. 

### API Unification

One of the best features of tree-based navigation is that it unifies all forms of navigation with a
single style of API. First of all, regardless of the type of navigation you plan on performing,
integrating the parent and child features together can be done with the single
``Reducer/ifLet(_:action:destination:fileID:line:)-4f2at`` operator. This one single API services
all forms of optional-driven navigation.

And then in the view, whether you are wanting to perform a drill-down, show a sheet, display
an alert, or even show a custom navigation component, all you need to do is invoke an API that
is provided a store focused on some ``PresentationState`` and ``PresentationAction``. If you do
that, then the API can handle the rest, making sure to present the child view when the state
becomes non-`nil` and dismissing when it goes back to `nil`.

This means that theoretically you could have a single view that needs to be able to show a sheet,
popover, drill-down, alert _and_ confirmation dialog, and all of the work to display the various
forms of navigation could be as simple as this:

```swift
.sheet(
  item: $store.scope(state: \.addItem, action: \.addItem)
) { store in 
  AddFeatureView(store: store)
}
.popover(
  item: $store.scope(state: \.editItem, action: \.editItem)
) { store in 
  EditFeatureView(store: store)
}
.navigationDestination(
  item: $store.scope(state: \.detailItem, action: \.detailItem)
) { store in 
  DetailFeatureView(store: store)
}
.alert(
  $store.scope(state: \.alert, action: \.alert)
)
.confirmationDialog(
  $store.scope(state: \.confirmationDialog, action: \.confirmationDialog)
)
```

In each case we provide a store scoped to the presentation domain, and a view that will be presented
when its corresponding state flips to non-`nil`. It is incredibly powerful to see that so many
seemingly disparate forms of navigation can be unified under a single style of API.

#### Backwards compatible availability

Depending on your deployment target, certain APIs may be unavailable. For example, if you target
iOS 16, you will not have access to iOS 17's `navigationDestination(item:)` view modifier. You can
easily backport the tool to work on older platforms by defining a wrapper for the API that calls
down to the available `navigationDestination(isPresented:)` API. Just paste the following into your
project:

```swift
extension View {
  @available(iOS, introduced: 16, deprecated: 17)
  @available(macOS, introduced: 13, deprecated: 14)
  @available(tvOS, introduced: 16, deprecated: 17)
  @available(watchOS, introduced: 9, deprecated: 10)
  @ViewBuilder
  func navigationDestinationWrapper<D: Hashable, C: View>(
    item: Binding<D?>,
    @ViewBuilder destination: @escaping (D) -> C
  ) -> some View {
    navigationDestination(isPresented: item.isPresented) {
      if let item = item.wrappedValue {
        destination(item)
      }
    }
  }
}

fileprivate extension Optional where Wrapped: Hashable {
  var isPresented: Bool {
    get { self != nil }
    set { if !newValue { self = nil } }
  }
}
```

If you target platforms earlier than iOS 16, macOS 13, tvOS 16 and watchOS 9, then you cannot use
`navigationDestination` at all. Instead you can use `NavigationLink`, but you must define another
helper for driving navigation off of a binding of data rather than just a simple boolean. Just paste
the following into your project:

```swift
@available(iOS, introduced: 13, deprecated: 16)
@available(macOS, introduced: 10.15, deprecated: 13)
@available(tvOS, introduced: 13, deprecated: 16)
@available(watchOS, introduced: 6, deprecated: 9)
extension NavigationLink {
  public init<D, C: View>(
    item: Binding<D?>,
    @ViewBuilder destination: (D) -> C,
    @ViewBuilder label: () -> Label
  ) where Destination == C? {
    self.init(
      destination: item.wrappedValue.map(destination),
      isActive: Binding(
        get: { item.wrappedValue != nil },
        set: { isActive, transaction in
          if !isActive {
            item.transaction(transaction).wrappedValue = nil
          }
        }
      ),
      label: label
    )
  }
}
```

## Integration

Once your features are integrated together using the steps above, your parent feature gets instant
access to everything happening inside the child feature. You can use this as a means to integrate
the logic of child and parent features. For example, if you want to detect when the "Save" button
inside the edit feature is tapped, you can simply destructure on that action. This consists of
pattern matching on the ``PresentationAction``, then the ``PresentationAction/presented(_:)`` case,
then the feature you are interested in, and finally the action you are interested in:

```swift
case .destination(.presented(.editItem(.saveButtonTapped))):
  // ...
```

Once inside that case you can then try extracting out the feature state so that you can perform
additional logic, such as closing the "edit" feature and saving the edited item to the database:

```swift
case .destination(.presented(.editItem(.saveButtonTapped))):
  guard case let .editItem(editItemState) = state.destination
  else { return .none }

  state.destination = nil
  return .run { _ in
    self.database.save(editItemState.item)
  }
```

## Dismissal

Dismissing a presented feature is as simple as `nil`-ing out the state that represents the 
presented feature:

```swift
case .closeButtonTapped:
  state.destination = nil
  return .none
```

In order to `nil` out the presenting state you must have access to that state, and usually only the
parent has access, but often we would like to encapsulate the logic of dismissing a feature to be
inside the child feature without needing explicit communication with the parent.

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

When `self.dismiss()` is invoked, SwiftUI finds the closest parent view with a presentation, and
causes it to dismiss by writing `false` or `nil` to the binding that drives the presentation. This 
can be incredibly useful, but it is also relegated to the view layer. It is not possible to use 
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
      }
    }
  }
}
```

> Note: The ``DismissEffect`` function is async which means it cannot be invoked directly inside a 
> reducer. Instead it must be called from ``Effect/run(priority:operation:catch:fileID:line:)``.

When `self.dismiss()` is invoked it will `nil` out the state responsible for presenting the feature
by sending a ``PresentationAction/dismiss`` action back into the system, causing the feature to be
dismissed. This allows you to encapsulate the logic for dismissing a child feature entirely inside 
the child domain without explicitly communicating with the parent.

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
> To do so would be to send an action for a feature while its state is `nil`, and that will cause
> a runtime warning in Xcode and a test failure when running tests.

> Warning: SwiftUI's environment value `@Environment(\.dismiss)` and the Composable Architecture's
> dependency value `@Dependency(\.dismiss)` serve similar purposes, but are completely different 
> types. SwiftUI's environment value can only be used in SwiftUI views, and this library's
> dependency value can only be used inside reducers.

## Testing

A huge benefit of properly modeling your domains for navigation is that testing becomes quite easy.
Further, using "non-exhaustive testing" (see <doc:Testing#Non-exhaustive-testing>) can be very 
useful for testing navigation since you often only want to assert on a few high level details and 
not all state mutations and effects.

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

And then let's embed that feature into a parent feature using the ``Presents()`` macro, 
``PresentationAction`` type and ``Reducer/ifLet(_:action:destination:fileID:line:)-4f2at``
operator:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable {
    @Presents var counter: CounterFeature.State?
  }
  enum Action {
    case counter(PresentationAction<CounterFeature.Action>)
  }
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      // Logic and behavior for core feature.
    }
    .ifLet(\.$counter, action: \.counter) {
      CounterFeature()
    }
  }
}
```

Now let's try to write a test on the `Feature` reducer that proves that when the child counter 
feature's count is incremented above 5 it will dismiss itself. To do this we will construct a 
``TestStore`` for `Feature` that starts in a state with the count already set to 3:

```swift
func testDismissal() {
  let store = TestStore(
    initialState: Feature.State(
      counter: CounterFeature.State(count: 3)
    )
  ) {
    CounterFeature()
  }
}
```

Then we can send the `.incrementButtonTapped` action in the counter child feature to confirm
that the count goes up by one:

```swift
await store.send(\.counter.incrementButtonTapped) {
  $0.counter?.count = 4
}
```

And then we can send it one more time to see that the count goes up to 5:

```swift 
await store.send(\.counter.incrementButtonTapped) {
  $0.counter?.count = 5
}
```

And then we finally expect that the child dismisses itself, which manifests itself as the 
``PresentationAction/dismiss`` action being sent to `nil` out the `counter` state, which we can
assert using the ``TestStore/receive(_:timeout:assert:file:line:)-6325h`` method on ``TestStore``:

```swift
await store.receive(\.counter.dismiss) {
  $0.counter = nil
}
```

This shows how we can write very nuanced tests on how parent and child features interact with each
other.

However, the more complex the features become, the more cumbersome testing their integration can be.
By default, ``TestStore`` requires us to be exhaustive in our assertions. We must assert on how
every piece of state changes, how every effect feeds data back into the system, and we must make
sure that all effects finish by the end of the test (see <doc:Testing> for more info).

But ``TestStore`` also supports a form of testing known as "non-exhaustive testing" that allows you
to assert on only the parts of the features that you actually care about (see 
<doc:Testing#Non-exhaustive-testing> for more info).

For example, if we turn off exhaustivity on the test store (see ``TestStore/exhaustivity``) then we
can assert at a high level that when the increment button is tapped twice that eventually we receive
a dismiss action:

```swift
func testDismissal() {
  let store = TestStore(
    initialState: Feature.State(
      counter: CounterFeature.State(count: 3)
    )
  ) {
    CounterFeature()
  }
  store.exhaustivity = .off

  await store.send(\.counter.incrementButtonTapped)
  await store.send(\.counter.incrementButtonTapped)
  await store.receive(\.counter.dismiss) 
}
```

This essentially proves the same thing that the previous test proves, but it does so in much fewer
lines and is more resilient to future changes in the features that we don't necessarily care about.

That is the basics of testing, but things get a little more complicated when you leverage the 
concepts outlined in <doc:TreeBasedNavigation#Enum-state> in which you model multiple destinations
as an enum instead of multiple optionals. In order to assert on state changes when using enum
state you must chain into the particular case to make a mutation:

```swift
await store.send(\.destination.counter.incrementButtonTapped) {
  $0.destination?.counter?.count = 4
}
```
