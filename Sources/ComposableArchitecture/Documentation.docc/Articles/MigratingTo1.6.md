# Migrating to 1.6

Update your code to make use of the new observation tools in the library and get rid of legacy
APIs such as ``WithViewStore``, ``IfLetStore``, ``ForEachStore``, and more.

## Overview

The Composable Architecture is under constant development, and we are always looking for ways to
simplify the library, and make it more powerful. As such, we often need to deprecate certain APIs
in favor of newer ones. We recommend people update their code as quickly as possible to the newest
APIs, and this article contains some tips for doing so.

* [Using @ObservableState](#Using-ObservableState)

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
+    WithViewStore(self.store) {  
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
* Do not pass the `observe` argument to ``WithViewStore`` and the trailing closure no longer takes
an argument. The view will automatically observe only the state accessed in the view.
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

You no longer need the ``WithViewStore`` at all.

## Replacing IfLetStore with 'if let'

The ``IfLetStore`` view is a helper for transforming a ``Store`` of optional state into a store of
non-optional state so that it can be handed off to a child view. For example, if your feature's 
reducer looks roughly like this:

```swift
@Reducer
struct Feature {
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

The ``ForEachStore`` view is a helper for deriving a store for each element of a collection. For
example, if your feature's reducer looks roughly like this:

```swift
@Reducer
struct Feature {
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

## Replacing navigation view modifiers with SwiftUI modifiers

## View actions


## TBD
