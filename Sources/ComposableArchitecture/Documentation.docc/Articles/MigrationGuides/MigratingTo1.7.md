# Migrating to 1.7

Update your code to make use of the new observation tools in the library and get rid of legacy
APIs such as ``WithViewStore``, ``IfLetStore``, ``ForEachStore``, and more.

## Overview

The Composable Architecture is under constant development, and we are always looking for ways to
simplify the library, and make it more powerful. As such, we often need to deprecate certain APIs
in favor of newer ones. We recommend people update their code as quickly as possible to the newest
APIs, and this article contains some tips for doing so.

> Important: Before following this migration guide be sure you have fully migrated to the newest
tools of version 1.6. See <doc:MigratingTo1.4>, <doc:MigratingTo1.5>, and <doc:MigratingTo1.6> for
more information.

> Note: The following migration guide mostly assumes you are targeting iOS 17, macOS 14, tvOS 17, 
watchOS 10 or higher, but the tools do work for older platforms too. See the dedicated 
<doc:ObservationBackport> article for more information on how to use the new observation tools if
you are targeting older platforms.

### Topics

* [Using @ObservableState](#Using-ObservableState)
* [Replacing IfLetStore with ‘if let’](#Replacing-IfLetStore-with-if-let)
* [Replacing ForEachStore with ForEach](#Replacing-ForEachStore-with-ForEach)
* [Replacing SwitchStore and CaseLet with ‘switch’ and ‘case’](#Replacing-SwitchStore-and-CaseLet-with-switch-and-case)
* [Replacing @PresentationState with @Presents](#Replacing-PresentationState-with-Presents)
* [Replacing navigation view modifiers with SwiftUI modifiers](#Replacing-navigation-view-modifiers-with-SwiftUI-modifiers)
* [Updating alert and confirmationDialog](#Updating-alert-and-confirmationDialog)
* [Replacing NavigationStackStore with NavigationStack](#Replacing-NavigationStackStore-with-NavigationStack)
* [@BindingState](#BindingState)
* [ViewStore.binding](#ViewStorebinding)
* [Computed view state](#Computed-view-state)
* [View actions](#View-actions)
* [Observing for UIKit](#Observing-for-UIKit)
* [Incrementally migrating](#Incrementally-migrating)

## Using @ObservableState

There are two ways to update existing code to use the new ``ObservableState()`` macro depending on
your minimum deployment target. Take, for example, the following scaffolding of a typical feature 
built with the Composable Architecture prior to version 1.7 and the new observation tools:

```swift
@Reducer
struct Feature {
  struct State { /* ... */ }
  enum Action { /* ... */ }
  var body: some ReducerOf<Self> {
    // ...
  }
}

struct FeatureView: View {
  let store: StoreOf<Feature>

  struct ViewState: Equatable {
    // ...
    init(state: Feature.State) { /* ... */ }
  }

  var body: some View {
    WithViewStore(store, observe: ViewState.init) { viewStore in
      Form {
        Text(viewStore.count.description)
        Button("+") { viewStore.send(.incrementButtonTapped) }
      }
    }
  }
}
```

This feature is manually managing a `ViewState` struct and using ``WithViewStore`` in order to
minimize the state being observed in the view.

If you are still targeting iOS 16, macOS 13, tvOS 16, watchOS 9 or _lower_, then you can update the
code in the following way:

```diff
 @Reducer
 struct Feature {
+  @ObservableState
   struct State { /* ... */ }
   enum Action { /* ... */ }
   var body: some ReducerOf<Self> {
     // ...
   }
 }
 
 struct FeatureView: View {
   let store: StoreOf<Feature>
 
-  struct ViewState: Equatable {
-    // ...
-    init(state: Feature.State) { /* ... */ }
-  }
 
   var body: some View {
-    WithViewStore(store, observe: ViewState.init) { viewStore in
+    WithPerceptionTracking {
       Form {
-        Text(viewStore.count.description)
-        Button("+") { viewStore.send(.incrementButtonTapped) }
+        Text(store.count.description)
+        Button("+") { store.send(.incrementButtonTapped) }
       }
     }
   }
 }
```

In particular, the following changes must be made:

  * Mark your `State` with the ``ObservableState()`` macro.
  * Delete any view state type you have defined.
  * Replace the use of ``WithViewStore`` with `WithPerceptionTracking`, and the trailing closure
    does not take an argument. The view constructed inside the trailing closure will automatically
    observe state accessed inside the closure.
  * Access state directly in the `store` rather than in the `viewStore`.
  * Send actions directly to the `store` rather than to the `viewStore`.

If you are able to target iOS 17, macOS 14, tvOS 17, watchOS 10 or _higher_, then you will still
apply all of the updates above, but with one additional simplification to the `body` of the view:

```diff
 var body: some View {
-  WithViewStore(store, observe: ViewState.init) { viewStore in
     Form {
-      Text(viewStore.count.description)
-      Button("+") { viewStore.send(.incrementButtonTapped) }
+      Text(store.count.description)
+      Button("+") { store.send(.incrementButtonTapped) }
     }
-  }
 }
```

You no longer need the ``WithViewStore`` or `WithPerceptionTracking` views at all.

## Replacing IfLetStore with 'if let'

The ``IfLetStore`` view was a helper for transforming a ``Store`` of optional state into a store of
non-optional state so that it can be handed off to a child view. It is no longer needed when using
the new observation tools, and so it is **soft-deprecated**.

For example, if your feature's reducer looks roughly like this:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State {
    var child: Child.State?
  }
  enum Action {
    case child(Child.Action)
  }
  var body: some ReducerOf<Self> { /* ... */ }
}
```

Then previously you would make use of ``IfLetStore`` in the view like this:

```swift
IfLetStore(store: store.scope(state: \.child, action: \.child)) { childStore in
  ChildView(store: childStore)
} else: {
  Text("Nothing to show")
}
```

This can now be updated to use plain `if let` syntax with ``Store/scope(state:action:)-36e72``:

```swift
if let childStore = store.scope(state: \.child, action: \.child) {
  ChildView(store: childStore)
} else {
  Text("Nothing to show")
}
```

## Replacing ForEachStore with ForEach

The ``ForEachStore`` view was a helper for deriving a store for each element of a collection. It is 
no longer needed when using the new observation tools, and so it is **soft-deprecated**.

For example, if your feature's reducer looks roughly like this:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State {
    var rows: IdentifiedArrayOf<Child.State> = []
  }
  enum Action {
    case rows(IdentifiedActionOf<Child>)
  }
  var body: some ReducerOf<Self> { /* ... */ }
}
```

Then you would have made use of ``ForEachStore`` in the view like this:

```swift
ForEachStore(
  store.scope(state: \.rows, action: \.rows)
) { childStore in
  ChildView(store: childStore)
}
```

This can now be updated to use the vanilla `ForEach` view in SwiftUI, along with 
``Store/scope(state:action:)-1nelp``, identified by the state of each row:

```swift
ForEach(
  store.scope(state: \.rows, action: \.rows),
  id: \.state.id
) { childStore in
  ChildView(store: childStore)
}
```

If your usage of `ForEachStore` did not depend on the identity of the state of each row (_e.g._, the
state's `id` is not associated with a selection binding), you can omit the `id` parameter, as the
`Store` type is identifiable by its object identity:

```diff
 ForEach(
-  store.scope(state: \.rows, action: \.rows),
-  id: \.state.id,
+  store.scope(state: \.rows, action: \.rows)
 ) { childStore in
   ChildView(store: childStore)
 }
```

> Tip: You can now use collection-based operators with store scoping. For example, use
> `Array.enumerated` in order to enumerate the rows so that you can provide custom styling based on
> the row being even or odd:
>
> ```swift
> ForEach(
>   Array(store.scope(state: \.rows, action: \.rows).enumerated()),
>   id: \.element
> ) { position, childStore in
>   ChildView(store: childStore)
>     .background {
>       position.isMultiple(of: 2) ? Color.white : Color.gray
>     }
> }
> ```

## Replacing SwitchStore and CaseLet with 'switch' and 'case'

The ``SwitchStore`` and ``CaseLet`` views are helpers for driving a ``Store`` for each case of 
an enum. These views are no longer needed when using the new observation tools, and so they are
**soft-deprecated**. 

For example, if your feature's reducer looks roughly like this:

```swift
@Reducer 
struct Feature {
  @ObservableState
  enum State {
    case activity(ActivityFeature.State)
    case settings(SettingsFeature.State)
  }
  enum Action {
    case activity(ActivityFeature.Action)
    case settings(SettingsFeature.Action)
  }
  var body: some ReducerOf<Self> { /* ... */ }
}
```

Then you would have used ``SwitchStore`` and ``CaseLet`` in the view like this:

```swift
SwitchStore(store) {
  switch $0 {
  case .activity:
    CaseLet(/Feature.State.activity, action: Feature.Action.activity) { store in
      ActivityView(store: store)
    }
  case .settings:
    CaseLet(/Feature.State.settings, action: Feature.Action.settings) { store in
      SettingsView(store: store)
    }
  }
}
```

This can now be updated to use a vanilla `switch` and `case` in the view:

```swift
switch store.state {
case .activity:
  if let store = store.scope(state: \.activity, action: \.activity) {
    ActivityView(store: store)
  }
case .settings:
  if let store = store.scope(state: \.settings, action: \.settings) {
    SettingsView(store: store)
  }
}
```

## Replacing @PresentationState with @Presents

It is a well-known limitation of Swift macros that they cannot be used with property wrappers.
This means that if your feature uses ``PresentationState`` you will get compiler errors when 
applying the ``ObservableState()`` macro:

```swift
@ObservableState 
struct State {
  @PresentationState var child: Child.State?  // 🛑
}
```

Instead of using the ``PresentationState`` property wrapper you can now use the new ``Presents()`` 
macro:

```swift
@ObservableState 
struct State {
  @Presents var child: Child.State?  // ✅
}
```

## Replacing navigation view modifiers with SwiftUI modifiers

The library has shipped many navigation view modifiers that mimic what SwiftUI provides, but are
tuned specifically for driving navigation from a ``Store``. All of these view modifiers can be
updated to instead use the vanilla SwiftUI version of the view modifier, and so the modifier that
ship with this library are now soft-deprecated.

For example, if your feature's reducer looks roughly like this:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State {
    @Presents var child: Child.State?
  }
  enum Action {
    case child(PresentationAction<Child.Action>)
  }
  var body: some ReducerOf<Self> { /* ... */ }
}
```

Then previously you would drive a sheet presentation from the view like so:

```swift
.sheet(store: store.scope(state: \.$child, action: \.child)) { store in
  ChildView(store: store)
}
```

You can now replace `sheet(store:)` with the vanilla SwiftUI modifier, `sheet(item:)`. First you
must hold onto the store in your view in a bindable manner, using the `@Bindable` property wrapper:

```swift
@Bindable var store: StoreOf<Feature>
```

…or, if you're targeting older platforms, using `@Perception.Bindable`:

```swift
@Perception.Bindable var store: StoreOf<Feature>
```

Then you can use `sheet(item:)` like so:

```swift
.sheet(item: $store.scope(state: \.child, action: \.child)) { store in
  ChildView(store: store)
}
```

Note that the state key path is simply `state: \.child`, and not `state: \.$child`. The projected
value of the presentation state is no longer needed.

This also applies to popovers, full screen covers, and navigation destinations.

Also, if you are driving navigation from an enum of destinations, then currently your code may
look something like this:

```swift
.sheet(
  store: store.scope(
    state: \.$destination.editForm,
    action: \.destination.editForm
  )
) { store in
  ChildView(store: store)
}
```

This can now be changed to this:

```swift
.sheet(
  item: $store.scope(
    state: \.destination?.editForm,
    action: \.destination.editForm
  )
) { store in
  ChildView(store: store)
}
```

Note that the state key path is now simply `\.destination?.editForm`, and not
`\.$destination.editForm`.

Also note that `navigationDestination(item:)` is not available on older platforms, but can be made
available as far back as iOS 15 using a wrapper. See
<doc:TreeBasedNavigation#Backwards-compatible-availability> for more information.

## Updating alert and confirmationDialog

The ``SwiftUI/View/alert(store:)`` and ``SwiftUI/View/confirmationDialog(store:)`` modifiers have
been used to drive alerts and dialogs from stores, but new modifiers are now available that can
drive alerts and dialogs from the same store binding scope operation that can power vanilla SwiftUI
presentation, like `sheet(item:)`.

For example, if your feature's reducer presents an alert:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State {
    @Presents var alert: AlertState<Action.Alert>?
  }
  enum Action {
    case alert(PresentationAction<Alert>)
    enum Alert { /* ... */ }
  }
  var body: some ReducerOf<Self> { /* ... */ }
}
```

Then previously you would drive it from the feature's view like so:

```swift
.alert(store: store.scope(state: \.$alert, action: \.alert))
```

You can now replace `alert(store:)` with a new modifier, ``SwiftUI/View/alert(_:)``:

```swift
.alert($store.scope(state: \.alert, action: \.alert))
```

## Replacing NavigationStackStore with NavigationStack

The ``NavigationStackStore`` view was a helper for driving a navigation stack from a ``Store``. It 
is no longer needed when using the new observation tools, and so it is **soft-deprecated**.

For example, if your feature's reducer looks roughly like this:

```swift
@Reducer
struct Feature {
  struct State {
    var path: StackState<Path.State> = []
  }
  enum Action {
    case path(StackAction<Path.State, Path.Action>)
  }
  var body: some ReducerOf<Self> { /* ... */ }
}
```

Then you would have made use of ``NavigationStackStore`` in the view like this:

```swift
NavigationStackStore(store.scope(state: \.path, action: \.path)) {
  RootView()
} destination: {
  switch $0 {
  case .activity:
    CaseLet(/Feature.State.activity, action: Feature.Action.activity) { store in
      ActivityView(store: store)
    }
  case .settings:
    CaseLet(/Feature.State.settings, action: Feature.Action.settings) { store in
      SettingsView(store: store)
    }
  }
}
```

To update this code, first mark your feature's state with ``ObservableState()``:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State {
    // ...
  }
  // ...
}
```

As well as the `Path` reducer's state:

```swift
@Reducer
struct Path {
  @ObservableState
  enum State {
    // ...
  }
  // ...
}
```

Then in the view you must start holding onto the `store` in a bindable manner, using the `@Bindable`
property wrapper:

```swift
@Bindable var store: StoreOf<Feature>
```

…or using `@Perception.Bindable` if targeting older platforms:

```swift
@Perception.Bindable var store: StoreOf<Feature>
```

And the original code can now be updated to our custom initializer 
``SwiftUI/NavigationStack/init(path:root:destination:fileID:line:)`` on `NavigationStack`:

```swift
NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
  RootView()
} destination: { store in
  switch store.state {
  case .activity:
    if let store = store.scope(state: \.activity, action: \.activity) {
      ActivityView(store: store)
    }
  case .settings:
    if let store = store.scope(state: \.settings, action: \.settings) {
      SettingsView(store: store)
    }
  }
}
```

## @BindingState

Bindings in the Composable Architecture have historically been handled by a zoo of types, including
<doc:BindingState>, ``BindableAction``, ``BindingAction``, ``BindingViewState`` and 
``BindingViewStore``. For example, if your view needs to be able to derive bindings to many fields
on your state, you may have the reducer built somewhat like this:

```swift
@Reducer
struct Feature {
  struct State {
    @BindingState var text = ""
    @BindingState var isOn = false
  }
  enum Action: BindableAction {
    case binding(BindingAction<State>)
  }
  var body: some ReducerOf<Self> { /* ... */ }
}
```

And in the view you derive bindings using ``ViewStore/subscript(dynamicMember:)-3q4xh`` defined on
``ViewStore``:

```swift
WithViewStore(store, observe: { $0 }) { viewStore in
  Form {
    TextField("Text", text: viewStore.$text)
    Toggle(isOn: viewStore.$isOn)
  }
}
```

But if you have view state in your view, then you have a lot more steps to take:

```swift
struct ViewState: Equatable {
  @BindingViewState var text: String
  @BindingViewState var isOn: Bool
  init(store: BindingViewStore<Feature.State>) {
    self._text = store.$text
    self._isOn = store.$isOn
  }
}

var body: some View {
  WithViewStore(store, observe: ViewState.init) { viewStore in
    Form {
      TextField("Text", text: viewStore.$text)
      Toggle(isOn: viewStore.$isOn)
    }
  }
}
```

Most of this goes away when using the ``ObservableState()`` macro. You can start by annotating
your feature's state with ``ObservableState()`` and removing all instances of <doc:BindingState>:

```diff
+@ObservableState
 struct State {
-  @BindingState var text = ""
-  @BindingState var isOn = false
+  var text = ""
+  var isOn = false
 }
```

> Important: Do not remove the ``BindableAction`` conformance from your feature's `Action` or the
> ``BindingReducer`` from your reducer. Those are still required for bindings.

In the view you must start holding onto the `store` in a bindable manner, which means using the
`@Bindable` property wrapper:

```swift
@Bindable var store: StoreOf<Feature>
```

> Note: If targeting older Apple platforms where `@Bindable` is not available, you can use our
> backport of the property wrapper:
>
> ```swift
> @Perception.Bindable var store: StoreOf<Feature>
> ```

Then in the `body` of the view you can stop using ``WithViewStore`` and instead derive bindings 
directly from the store:

```swift
var body: some View {
  Form {
    TextField("Text", text: $store.text)
    Toggle(isOn: $store.isOn)
  }
}
```

## ViewStore.binding

There's another way to derive bindings from a view store that involves fewer tools than 
`@BindingState` as shown above, but does involve more boilerplate. You can add an explicit action
for the binding to your domain, such as an action for setting the tab in a tab-based application:

```swift
@Reducer 
struct Feature {
  struct State {
    var tab = 0
  }
  enum Action {
    case tabChanged(Int)
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .tabChanged(tab):
        state.tab = tab
        return .none
      }
    }
  }
}
```

And then in the view you can use ``ViewStore/binding(get:send:)-65xes`` to derive a binding from
the `tab` state and the `tabChanged` action:

```swift
TabView(
  selection: viewStore.binding(get: \.tab, send: { .tabChanged($0) })
) {
  // ...
}
```

Since the ``ViewStore`` type is now soft-deprecated, you can update this code to do something much
simpler. If you make your feature's state observable with the ``ObservableState`` macro:

```swift
@Reducer 
struct Feature {
  @ObservableState
  struct State {
    // ...
  }
  // ...
}
```

In the view you must start holding onto the `store` in a bindable manner, which means using the
`@Bindable` (or `@Perception.Bindable`) property wrapper:

```swift
@Bindable var store: StoreOf<Feature>
```

Then you can derive a binding directly from a ``Store`` binding like so:

```swift
TabView(selection: $store.tab.sending(\.tabChanged)) {
  // ...
}
```

If the binding depends on more complex business logic, you can define a custom `get`-`set` property
(or subscript, if this logic depends on external state) on the store to incorporate this logic. For
example:

@Row {
  @Column {
    ```swift
    // Before

    // In the view:
    ForEach(Flag.allCases) { flag in
      Toggle(
        flag.description,
        isOn: viewStore.binding(
          get: { $0.featureFlags.contains(flag) }
          send: { .flagToggled(flag, isOn: $0) }
        )
      )
    }
    ```
  }
  @Column {
    ```swift
    // After

    // In the file:
    extension StoreOf<Feature> {
      subscript(hasFeatureFlag flag: Flag) -> Bool {
        get { featureFlags.contains(flag) }
        set {
          send(.flagToggled(flag, isOn: newValue))
        }
      }
    }

    // In the view:
    ForEach(Flag.allCases) { flag in
      Toggle(
        flag.description,
        isOn: $store[hasFeatureFlag: flag]
      )
    }
    ```
  }
}

> Tip: When possible, consider moving complex binding logic into the reducer so that it can be more
> easily tested.

## Computed view state

If you are using the `ViewState` pattern in your application, then you may be computing values 
inside the initializer to be used in the view like so:

```swift
struct ViewState: Equatable {
  let fullName: String
  init(state: Feature.State) {
    self.fullName = "\(state.firstName) \(state.lastName)"
  }
}
```

In version 1.7 of the library the `ViewState` struct goes away, and so you can move these kinds of 
computations to be directly on your feature's state:

```swift
struct State {
  // State fields
  
  var fullName: String {
    "\(self.firstName) \(self.lastName)"
  }
}
```

## View actions

There is a common pattern in the Composable Architecture community to separate actions that are
sent in the view from actions that are used internally in the feature, such as emissions of effects.
Typically this looks like the following:

```swift
@Reducer
struct Feature
  struct State { /* ... */ }
  enum Action {
    case loginResponse(Bool)
    case view(View)

    enum View {
      case loginButtonTapped
    }
  }
  // ...
}
```

And then in the view you would use ``WithViewStore`` with the `send` argument to specify which 
actions the view has access to:

```swift
struct FeatureView: View {
  let store: StoreOf<Feature>

  var body: some View {
    WithViewStore(
      store, 
      observe: { $0 }, 
      send: Feature.Action.view  // 👈
    ) { viewStore in
      Button("Login") {
        viewStore.send(.loginButtonTapped) 
      }
    }
  }
}
```

That makes it so that you can send `view` actions without wrapping the action in `.view(…)`, and
it makes it so that you can only send `view` actions. For example, the view cannot send the
`loginResponse` action:

```swift
viewStore.send(.loginResponse(false))
// 🛑 Type 'Feature.Action.View' has no member 'loginResponse'
```

This pattern is still possible with version 1.7 of the library, but requires a few small changes.
First, you must make your `View` action enum conform to the ``ViewAction`` protocol:

```swift
@Reducer
struct Feature {
  // ...
  enum Action: ViewAction {  // 👈
    // ...
  }
  // ...
}
```

And second, you can use the ``ViewAction(for:)`` macro on your view by specifying the reducer that
powers the view. This gives you access to a `send` method in the view for sending view actions
rather than going through ``Store/send(_:)``:

```diff
+@ViewAction(for: Feature.self)
 struct FeatureView: View {
   let store: StoreOf<Feature>
 
   var body: some View {
-    WithViewStore(
-      store, 
-      observe: { $0 }, 
-      send: Feature.Action.view
-    ) { viewStore in
       Button("Login") { 
-        viewStore.send(.loginButtonTapped) 
+        send(.loginButtonTapped)
       }
     }
-  }
 }
```

## Observing for UIKit

Prior to the observation tools one would typically subscribe to changes in the store via a Combine
publisher in the entry point of a view, such as `viewDidLoad` in a `UIViewController` subclass:

```swift
func viewDidLoad() {
  super.viewDidLoad()

  store.publisher.count
    .sink { [weak self] in self?.countLabel.text = "\($0)" }
    .store(in: &cancellables)
}
```

This can now be done more simply using the ``ObjectiveC/NSObject/observe(_:)`` method defined on
all `NSObject`s:

```swift
func viewDidLoad() {
  super.viewDidLoad()

  observe { [weak self] in 
    guard let self 
    else { return }

    self.countLabel.text = "\(self.store.count)"
  }
}
```

Be sure to read the documentation for ``ObjectiveC/NSObject/observe(_:)`` to learn how to best 
wield this tool.

## Incrementally migrating

You are most likely going to want to incrementally migrate your application to the new observation tools, 
rather than doing everything all at once. That is possible, but there are some gotchas to be aware
of when mixing "legacy" features (_i.e._ features using ``ViewStore`` and ``WithViewStore``) with
"modern" features (_i.e._ features using ``ObservableState()``).

The most common problem one will encounter is that when legacy and modern features are mixed
together, their view bodies can be re-computed more often than necessary. This is due to the 
mixed modes of observation. Legacy features use the `objectWillChange` publisher to synchronously 
invalidate the view, whereas modern features use 
[`withObservationTracking`][with-obs-tracking-docs]. These are two fundamentally different tools,
and it can create a situation where views are invalidated multiple times separated by a thread hop,
making it impossible to coalesce the validations into a single one. That is what causes the body
to re-compute multiple times.

Typically a few extra body re-computations shouldn't be a big deal, but they can put strain on
SwiftUI's ability to figure out what state changed in a view, and can cause glitchiness and 
exacerbate navigation bugs. If you are noticing problems after converting one feature to use 
``ObservableState()``, then we recommend trying to convert a few more features that it interacts
with to see if the problems go away.

We have also found that modern features that contain legacy features as child features tend to 
behave better than the opposite. For this reason we recommend updating your features to use 
``ObservableState()`` from the outside in. That is, start with the root feature, update it to
use the new observation tools, and then work you way towards the leaf features.

[with-obs-tracking-docs]: https://developer.apple.com/documentation/observation/withobservationtracking(_:onchange:)
