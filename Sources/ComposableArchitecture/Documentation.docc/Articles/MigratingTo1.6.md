# Migrating to 1.6

Update your code to make use of the new observation tools in the library and get rid of legacy
APIs such as ``WithViewStore``, ``IfLetStore``, ``ForEachStore``, and more.

## Overview

The Composable Architecture is under constant development, and we are always looking for ways to
simplify the library, and make it more powerful. As such, we often need to deprecate certain APIs
in favor of newer ones. We recommend people update their code as quickly as possible to the newest
APIs, and this article contains some tips for doing so.

> Important: Before following this migration guide be sure you have fully migrated to the newest
tools of version 1.5. See <doc:MigratingTo1.4> and <doc:MigratingTo1.5> for more information.

> Note: The following migration guide mostly assumes you are targeting iOS 17, macOS 14, tvOS 17, 
watchOS 10 or higher, but the tools do work for older platforms too. See the dedicated 
<doc:ObservationBackport> article for more information on how to use the new observation tools if
you are targeting older platforms.

* [Using @ObservableState](#Using-ObservableState)
* [Replacing IfLetStore with ‘if let’](#Replacing-IfLetStore-with-if-let)
* [Replacing ForEachStore with ForEach](#Replacing-ForEachStore-with-ForEach)
* [Replacing SwitchStore and CaseLet with ‘switch’ and ‘case’](#Replacing-SwitchStore-and-CaseLet-with-switch-and-case)
* [Replacing navigation view modifiers with SwiftUI modifiers](#Replacing-navigation-view-modifiers-with-SwiftUI-modifiers)
* [Replacing NavigationStackStore with NavigationStack](#Replacing-NavigationStackStore-with-NavigationStack)
* [@BindingState](#BindingState)
* [ViewStore.binding](#ViewStorebinding)
* [View actions](#View-actions)
* [Incrementally migrating](#Incrementally-migrating)

## Using @ObservableState

There are two ways to update existing code to use the new ``ObservableState()`` macro depending on
your minimum deployment target. Take, for example, the following scaffolding of a typical feature 
built with the Composable Architecture prior to version 1.6 and the new observation tools:

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
-    WithViewStore(store, observe: ViewState.init) { store in
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
  * Access state directly in the `store` rather than `viewStore`.
  * Send actions directly to the `store` rather than `viewStore`.

If you are able to target iOS 17, macOS 14, tvOS 17, watchOS 10 or _higher_, then you will still
apply all of the updates above, but with one additional simplification to the `body` of the view:

```diff
 var body: some View {
-  WithViewStore(store, observe: ViewState.init) { store in
     Form {
-      Text(viewStore.count.description)
-      Button("+") { viewStore.send(.incrementButtonTapped) }
+      Text(store.count.description)
+      Button("+") { store.send(.incrementButtonTapped) }
     }
-  }
 }
```

You no longer need the ``WithViewStore`` or `WithPerceptionTracking` at all.

> When you apply the ``ObservableState()`` macro to state that presents child state via the
> ``PresentationState`` property wrapper, you will encounter a diagnostic directing you to use the
> ``Presents()`` macro instead, which will wrap the given field with ``PresentationState`` _and_
> instrument it with observation.

## Replacing IfLetStore with 'if let'

The ``IfLetStore`` view was a helper for transforming a ``Store`` of optional state into a store of
non-optional state so that it can be handed off to a child view. It is no longer needed when using
the new observation tools, and so it is **soft-deprecated**.

For example, if your feature's 
reducer looks roughly like this:

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
if let childStore = store.scope(state: \.child, action: \.child)) {
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
ForEachStore(store.scope(state: \.rows, action: \.rows)) { childStore in
  ChildView(store: childStore)
}
```

This can now be updated to use the vanilla `ForEach` view in SwiftUI, along with 
``Store/scope(state:action:)-88iqh``:

```swift
ForEach(store.scope(state: \.rows, action: \.rows)) { childStore in
  ChildView(store: childStore)
}
```

Note that you can even use `Array.enumerated` in order to enumerate the rows so that you can provide
custom styling based on the row being even or odd:

```swift
ForEach(
  Array(store.scope(state: \.rows, action: \.rows).enumerated()),
  id: \.element
) { position, childStore in
  ChildView(store: childStore)
    .background {
      position.isMultiple(of: 2) ? Color.white : Color.gray
    }
}
```

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

Then previously you would drive a sheet presentation from this feature like so:

```swift
.sheet(store: store.scope(state: \.$child, action: \.child)) { store in
  ChildView(store: store)
}
```

You can now replace `sheet(store:)` with the vanilla SwiftUI modifier, `sheet(item:)`. First you
must hold onto the store in your view in a bindable manner, using `@State`:

```swift
@State var store: StoreOf<Feature>
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

Note that the state key path is simply `state: \.destination?.editForm`, and not 
`state: \.$destination.editForm`.

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

Then in the view you must start holding onto the `store` as `@State`:

```swift
@State var store: StoreOf<Feature>
```

And the original code can now be updated to our custom initializer on `NavigationStack`:

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
``BindingState``, ``BindableAction``, ``BindingAction``, ``BindingViewState`` and 
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
your feature's state with ``ObservableState()`` and removing all instances of ``BindingState``:

```diff
+@ObservableState
 struct State {
-  @BindingState var text = ""
-  @BindingState isOn = false
+  var text = ""
+  var isOn = false
 }
```

In the view you must start holding onto the `store` as `@State`:

```swift
@State var store: StoreOf<Feature>
```

In the `body` of the view you can stop using ``WithViewStore`` and instead derive bindings directly
from the store:

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
  selection: viewStore.binding(get: \.tab, send: Feature.Action.tabChanged)
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

In the view you must start holding onto the `store` as `@State`:

```swift
@State var store: StoreOf<Feature>
```

Then you can derive a binding directly from a ``Store`` binding like so:

```swift
TabView(selection: $store.tab.sending(\.tabChanged)) {
  // ...
}
```

<!--## View actions-->
<!--TODO-->

## Incrementally migrating

You are most likely going to want to incrementally your application to the new observation tools, 
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
