# Migrating to 1.25

This release introduces new APIs, including enum scopes and a streamlined `onChange` operator, and
deprecates a number of older APIs in preparation for Composable Architecture 2.0.

## Overview

Version 1.25 includes both new features and a significant batch of deprecations that pave the way
for Composable Architecture 2.0. Many of the deprecations are "trait" deprecations that only emit
warnings when package traits are enabled. You can enable them in your `Package.swift`:

```swift
.package(
  url: "https://github.com/pointfreeco/swift-composable-architecture",
  from: "1.25.0",
  traits: [
    "ComposableArchitecture2Deprecations",
    "ComposableArchitecture2DeprecationOverloads"
  ]
)
```

…or in your project settings, starting from Xcode 26.4.

  * `ComposableArchitecture2Deprecations` is meant to be left enabled, to catch new deprecations in
    new versions of Composable Architecture 1.0.
  * `ComposableArchitecture2DeprecationOverloads` is meant to be enabled temporarily during
    migration, as they introduce overloads that can regress compile times in your applications.

These traits allow you to incrementally adopt the changes at your own pace. Hard deprecations, on
the other hand, will always emit warnings regardless of the trait.

## New features

### Enum scopes

A new scope API has been introduced for enum-based presentation destinations. Instead of scoping
directly to a specific case of a destination enum, you now scope to the entire destination and then
chain into the individual case:

```diff
-.alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
+.alert($store.scope(state: \.$destination, action: \.destination).alert)

-.sheet(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) {
+.sheet(item: $store.scope(state: \.$destination, action: \.destination).edit) {
```

This provides a cleaner separation between the destination enum and its cases, and aligns with
how scoping will work in Composable Architecture 2.0.

One important difference in the new scoping operation is that it no longer wraps non-reducer cases
in a `Store`, and instead provides direct access to the data. This does mean that the data must
conform to `Identifiable`, or if it is an empty case (which produces `Optional<Void>`), you must
migrate to the `isPresented` view modifier and use `Binding.init` to convert `Optional<Void>`
bindings to `Bool` bindings:

```diff
-.sheet(item: $store.scope(state: \.destination?.help, action: \.destination.help)) { _ in
+.sheet(
+  isPresented: Binding($store.scope(state: \.$destination, action: \.destination).help)
+) {
```

### Streamlined `onChange` operator

A new overload of the `onChange` operator has been added that directly returns an effect instead
of requiring a full reducer to be constructed:

```diff
 BindingReducer()
-  .onChange(of: \.userSettings.isHapticFeedbackEnabled) { oldValue, newValue in
-    Reduce { state, action in
-      .run { send in
-        // Persist new value...
-      }
-    }
-  }
+  .onChange(of: \.userSettings.isHapticFeedbackEnabled) { oldValue, state in
+    .run { [newValue = state.userSettings.isHapticFeedbackEnabled] send in
+      // Persist new value...
+    }
+  }
```

## Hard deprecations

The following APIs now emit deprecation warnings unconditionally.

### `BindingViewState`/`BindingViewStore`

These types were obsoleted back in version 1.7 by the ``ObservableState()`` macro. Derive bindings
directly from stores using `@ObservableState` instead. See <doc:MigratingTo1.7#BindingState> for
more information.

### `Store.withState`

Use `@ObservableState` to observe state changes directly. See
<doc:MigratingTo1.7#Using-ObservableState> for more information.

### Combine/animation-scheduling effects

The following Combine-based effect operators have been hard deprecated:

- `Effect.animation(_:)` — Use `send(_:animation:)` from within a `.run` effect instead.
- `Effect.transaction(_:)` — Use `send(_:transaction:)` from within a `.run` effect instead.
- `Effect.debounce(id:for:scheduler:)` — Use `clock.sleep()` with
  `cancellable(id:cancelInFlight:)` in a `.run` effect instead.
- `Effect.throttle(id:for:scheduler:latest:)` — Use a manual throttle approach with clock-based
  scheduling in a `.run` effect instead.

For example:

```diff
-return .run { send in await send(.response(value)) }
-  .animation()
+return .run { send in
+  await send(.response(value), animation: .default)
+}
```

### Enum state `Scope`

Using `Scope(state:action:) { ... }` for enum state has been deprecated. Use a `@Reducer enum` or
`ifCaseLet(_:action:)` on a base reducer instead.

### `Reducer.reduce`

Directly invoking `reducer.reduce(into:action:)` is deprecated. Actions should be sent through the
store _via_ `store.send(_:)` or `Effect.send`.

## Trait deprecations

The following APIs are deprecated only when the `ComposableArchitecture2Deprecations` package trait
is enabled, allowing you to prepare for 2.0 on your own timeline.

> 1.25.0 temporarily deprecated the `Effect` type for `EffectOf`. This change is no longer
> necessary in the Composable 2.0 migration story.

### `Effect.concatenate`, `Effect.map`

These operators are deprecated. Sequence work directly in a `.run` effect using async/await
instead of concatenating, and construct effects directly in a feature instead of mapping them.

### `StorePublisher`

Using `store.publisher` for Combine-based observation is deprecated. Use observation APIs
(`observe`, `Observations`) instead.

### `$store.scope(state: \.destination)` (non-projected syntax)

Using `$store.scope(state: \.destination, ...)` with a non-projected key path is deprecated.
Use the projected key path syntax instead:

```diff
-.sheet(item: $store.scope(state: \.destination?.edit, action: \.destination.edit))
+.sheet(item: $store.scope(state: \.$destination, action: \.destination).edit)
```

### `onChange` with reducer builder

The older `onChange` overload that takes a reducer builder with `(oldValue, newValue)` is
deprecated. Use the new streamlined version described above.

## Reentrant action warnings

Sending an action while another action is being processed will now emit a runtime warning.
This is undefined behavior and will become a precondition failure in a future version of the
library. If you encounter this warning, restructure your code to avoid sending actions
synchronously from within action-processing code paths.
