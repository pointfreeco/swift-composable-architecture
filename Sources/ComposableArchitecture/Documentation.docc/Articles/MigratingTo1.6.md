# Migrating to 1.6

Update your code to make use of the new observation tools in the library and get rid of legacy
APIs such as ``WithViewStore``, ``IfLetStore``, ``ForEachStore``, and more.

## Overview

The Composable Architecture is under constant development, and we are always looking for ways to
simplify the library, and make it more powerful. As such, we often need to deprecate certain APIs
in favor of newer ones. We recommend people update their code as quickly as possible to the newest
APIs, and this article contains some tips for doing so.

* [Using @ObservableState](#Using-ObservableState)
* [Replacing IfLetStore with ‘if let’](#Replacing-IfLetStore-with-if-let)
* [Replacing ForEachStore with ForEach](#Replacing-ForEachStore-with-ForEach)
* [Replacing SwitchStore and CaseLet with ‘switch’ and ‘case’](#Replacing-SwitchStore-and-CaseLet-with-switch-and-case)
* [Replacing navigation view modifiers with SwiftUI modifiers](#Replacing-navigation-view-modifiers-with-SwiftUI-modifiers)
* [Replacing NavigationStackStore with NavigationStack](#Replacing-NavigationStackStore-with-NavigationStack)
* [Bindings](#Bindings)
* [View actions](#View-actions)

## Using @ObservableState

There are two ways to update existing code to use the new ``ObservableState()`` macro depending on
your minimum deployment target. Take the following scaffolding of a typical feature built with
the Composable Architecture prior to version 1.6 and the new observation tools:

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
    WithViewStore(self.store, observe: ViewState.init) { viewStore in
      Form {
        Text(viewStore.count.description)
        Button("+") { viewStore.send(.incrementButtonTapped) }
      }
    }
  }
}
```

If you are still targeting iOS 16, macOS 13, tvOS 16, watchOS 9 or _lower_, then you can update the
code in the following way:

```diff
 @Reducer
 struct Feature {
+  @Observable
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
-    WithViewStore(self.store, observe: ViewState.init) { store in
+    WithPerceptionTracking {
       Form {
-        Text(viewStore.count.description)
-        Button("+") { viewStore.send(.incrementButtonTapped) }
+        Text(self.store.count.description)
+        Button("+") { self.store.send(.incrementButtonTapped) }
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
-  WithViewStore(self.store, observe: ViewState.init) { store in
     Form {
-      Text(viewStore.count.description)
-      Button("+") { viewStore.send(.incrementButtonTapped) }
+      Text(self.store.count.description)
+      Button("+") { self.store.send(.incrementButtonTapped) }
     }
-  }
 }
```

You no longer need the ``WithViewStore`` or `WithPerceptionTracking` at all.

## Replacing IfLetStore with 'if let'

The ``IfLetStore`` view was a helper for transforming a ``Store`` of optional state into a store of
non-optional state so that it can be handed off to a child view. For example, if your feature's 
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

Then you would make use of ``IfLetStore`` in the view like this:

```swift
IfLetStore(store: self.store.scope(state: \.child, action: \.child)) { childStore in
  ChildView(store: childStore)
} else: {
  Text("Nothing to show")
}
```

This can now be updated to use plain `if let` syntax with ``Store/scope(state:action:)-36e72``:

```swift
if let childStore = self.store.scope(state: \.child, action: \.child)) {
  ChildView(store: childStore)
} else {
  Text("Nothing to show")
}
```

## Replacing ForEachStore with ForEach

The ``ForEachStore`` view was a helper for deriving a store for each element of a collection. For
example, if your feature's reducer looks roughly like this:

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

Then you would make use of ``ForEachStore`` in the view like this:

```swift
ForEachStore(self.store.scope(state: \.rows, action: \.rows)) { childStore in
  ChildView(store: childStore)
}
```

This can now be updated to use the vanilla `ForEach` view in SwiftUI, along with 
``Store/scope(state:action:)-88iqh``:

```swift
ForEach(self.store.scope(state: \.rows, action: \.rows)) { childStore in
  ChildView(store: childStore)
}
```

Note that you can even use `Array.enumerated` in order to enumerate the rows so that you can provide
custom styling based on the row being even or odd:

```swift
ForEach(
  Array(self.store.scope(state: \.rows, action: \.rows).enumerated()),
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
an enum. For example, if your feature's reducer looks roughly like this:

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

Then you would use ``SwitchStore`` and ``CaseLet`` in the view like this:

```swift
SwitchStore(self.store) {
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
switch self.store.state {
case .activity:
  if let store = self.store.scope(state: \.activity, action: \.activity) {
    ActivityView(store: store)
  }
case .settings:
  if let store = self.store.scope(state: \.settings, action: \.settings) {
    SettingsView(store: store)
  }
}
```

## Replacing navigation view modifiers with SwiftUI modifiers

The library has shipped many navigation view modifiers that mimic what SwiftUI provides, but are
tuned specifically for driving navigation from a ``Store``. All of these view modifiers can be
updated to instead use the vanilla SwiftUI version of the view modifier.

For example, if your feature's reducer looks roughly like this:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State {
    @PresentationState var child: Child.State?
  }
  enum Action {
    case child(PresentationAction<Child.State>
  }
  var body: some ReducerOf<Self> { /* ... */ }
}
```

Then previously you could drive a sheet presentation from this feature like so:

```swift
.sheet(store: self.store.scope(state: \.$child, action: \.child)) { store in
  ChildView(store: store)
}
```

You can now replace `sheet(store:)` with the vanilla SwiftUI modifier, `sheet(item:)`. First you
must hold onto the store in your view in a bindable manner, either using `@State`:

```swift
@State var store: StoreOf<Feature>
```

…or using the `@Bindable` property wrapper:

```swift
@Bindable var store: StoreOf<Feature>
```

Then you can use `sheet(item:)` like so:

```swift
.sheet(item: self.$store.scope(state: \.child, action: \.child)) { store in
  ChildView(store: store)
}
```

Note that `state: \.$child` is now simply `state: \.child`.

This also applies to popovers, full screen covers, and navigation destinations.

Also, if you are driving navigation from an enum of destinations, then currently your code may
look something like this:

```swift
.sheet(
  store: self.store.scope(
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
  item: self.$store.scope(
    state: \.destination?.editForm,
    action: \.destination.editForm
  )
) { store in
  ChildView(store: store)
}
```

Note that `state: \.$destination.editForm` is now simply `state: \.destination?.editForm`.

## Replacing NavigationStackStore with NavigationStack

The ``NavigationStackStore`` view was a helper for driving a navigation stack from a ``Store``. For
example, if your feature's reducer looks roughly like this:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State {
    var path: StackState<Path.State> = []
  }
  enum Action {
    case path(StackAction<Path.State, Path.Action>)
  }
  var body: some ReducerOf<Self> { /* ... */ }
}
```

Then you would make use of ``NavigationStackStore`` in the view like this:

```swift
NavigationStackStore(self.store.scope(state: \.path, action: \.path)) {
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

This can now be updated to use a custom initializer on `NavigationStack`:

```swift
NavigationStack(store: self.store.scope(state: \.path, action: \.path)) {
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

## Bindings

Bindings in the Composable Architecture have been handled by a zoo of types, including
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
WithViewStore(self.store, observe: { $0 }) { viewStore in
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
    self._text = bindingViewStore.$text
    self._isOn = bindingViewStore.$isOn
  }
}

var body: some View {
  WithViewStore(self.store, observe: ViewState.init) { viewStore in
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

In the view you must start holding onto the `store` as either `@State`:

```swift
@State var store: StoreOf<Feature>
```

…or `@Bindable`:

```swift
@Bindable var store: StoreOf<Feature>
```

In the `body` of the view you can stop using ``WithViewStore`` and instead derive bindings directly
from the store:

```swift
var body: some View {
  Form {
    TextField("Text", text: self.$store.text)
    Toggle(isOn: self.$store.isOn)
  }
}
```

## View actions

TODO
