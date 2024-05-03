# Migrating to 1.4

Update your code to make use of the ``Reducer()`` macro, and learn how to better leverage case key
paths in your features.

## Overview

The Composable Architecture is under constant development, and we are always looking for ways to
simplify the library, and make it more powerful. As such, we often need to deprecate certain APIs
in favor of newer ones. We recommend people update their code as quickly as possible to the newest
APIs, and this article contains some tips for doing so.

* [Using the @Reducer macro](#Using-the-Reducer-macro)
* [Using case key paths](#Using-case-key-paths)
* [Receiving test store actions](#Receiving-test-store-actions)
* [Moving off of `TaskResult`](#Moving-off-of-TaskResult)
* [Identified actions](#Identified-actions)

### Using the @Reducer macro

Version 1.4 of the library has introduced a new macro for automating certain aspects of implementing
a ``Reducer``. It is called ``Reducer()``, and to migrate existing code one only needs to annotate
their type with `@Reducer`:

```diff
+@Reducer
 struct MyFeature: Reducer {
   // ...
 }
```

No other changes to be made, and you can immediately start taking advantage of new capabilities of
reducer composition, such as case key paths (see guides below). See the documentation of
``Reducer()`` to see everything that macro adds to your feature's reducer.

You can also technically drop the ``Reducer`` conformance:

```diff
 @Reducer
-struct MyFeature: Reducer {
+struct MyFeature {
   // ...
 }
```

However, there are some known issues in Xcode that cause autocomplete and type inference to break.
See the documentation of <doc:Reducers#Gotchas> for more gotchas on using the `@Reducer` macro. 


### Using case key paths

In version 1.4 we soft-deprecated many APIs that take the `CasePath` type in favor of APIs that take
what is known as a `CaseKeyPath`. Both of these types come from our [CasePaths][swift-case-paths]
library and aim to allow one to abstract over the shape of enums just as key paths allow one to do
so with structs.

However, in conjunction with version 1.4 of this library we also released an update to CasePaths
that massively improved the ergonomics of using case paths. We introduced the `@CasePathable` macro
for automatically deriving case paths so that we could stop using runtime reflection, and we
introduced a way of using key paths to describe case paths. And so the old `CasePath` type has been
deprecated, and the new `CaseKeyPath` type has taken its place.

This means that previously when you would use APIs involving case paths you would have to use the
`/` prefix operator to derive the case path. For example:

```swift
Reduce { state, action in 
  // ...
}
.ifLet(\.child, action: /Action.child) {
  ChildFeature()
}
```

You now get to shorten that into a far simpler, more familiar key path syntax:

```swift
Reduce { state, action in 
  // ...
}
.ifLet(\.child, action: \.child) {
  ChildFeature()
}
```

To be able to take advantage of this syntax with your feature's actions, you must annotate your
``Reducer`` conformances with the ``Reducer()`` macro:

```swift
@Reducer
struct Feature {
  // ...
}
```

Which automatically applies the `@CasePathable` macro to the feature's `Action` enum among other
things:

```diff
+@CasePathable
 enum Action {
   // ...
 }
```

Further, if the feature's `State` is an enum, `@CasePathable` will also be applied, along with
`@dynamicMemberLookup`:

```diff
+@CasePathable
+@dynamicMemberLookup
 enum State {
   // ...
 }
```

Dynamic member lookups allows a state's associated value to be accessed via dot-syntax, which can be
useful when scoping a store's state to a specific case:

```diff
 IfLetStore(
   store.scope(
-    state: /Feature.State.tray, action: Feature.Action.tray
+    state: \.tray, action: { .tray($0) }
   )
) { store in
  // ...
}
```

To form a case key path for any other enum, you must apply the `@CasePathable` macro explicitly:

```swift
@CasePathable
enum DelegateAction {
  case didFinish(success: Bool)
}
```

And to access its associated values, you must also apply the `@dynamicMemberLookup` attributes:

```swift
@CasePathable
@dynamicMemberLookup
enum DestinationState {
  case tray(Tray.State)
}
```

Anywhere you previously used the `/` prefix operator for case paths you should now be able to use
key path syntax, so long as all of the enums involved are `@CasePathable`.

If you encounter any problems, create a [discussion][tca-discussions] on the Composable Architecture
repo.

### Receiving test store actions

The power of case key paths and the `@CasePathable` macro has made it possible to massively simplify
how one asserts on actions received in a ``TestStore``. Instead of constructing the concrete action
received from an effect like this:

```swift
store.receive(.child(.presented(.response(.success("Hello!")))))
```

…you can use key path syntax to describe the nesting of action cases that is received:

```swift
store.receive(\.child.presented.response.success)
```

> Note: Case key path syntax requires that every nested action is `@CasePathable`. Reducer actions
> are typically `@CasePathable` automatically via the ``Reducer()`` macro, but other enums must be
> explicitly annotated:
>
> ```swift
> @CasePathable
> enum DelegateAction {
>   case didFinish(success: Bool)
> }
> ```

And in the case of ``PresentationAction`` you can even omit the ``PresentationAction/presented(_:)``
path component:

```swift
store.receive(\.child.response.success)
```

This does not assert on the _data_ received in the action, but typically that is already covered
by the state assertion made inside the trailing closure of `receive`. And if you use this style of
action receiving exclusively, you can even stop conforming your action types to `Equatable`.

There are a few advanced situations to be aware of. When receiving an action that involves an 
``IdentifiedAction`` (more information below in <doc:MigratingTo1.4#Identified-actions>), then
you can use the subscript ``IdentifiedAction/AllCasePaths-swift.struct/subscript(id:)`` to 
receive a particular action for an element:

```swift
store.receive(\.rows[id: 0].response.success)
```

And the same goes for ``StackAction`` too:

```swift
store.receive(\.path[id: 0].response.success)
```

### Moving off of TaskResult

In version 1.4 of the library, the ``TaskResult`` was soft-deprecated and eventually will be fully
deprecated and then removed. The original rationale for the introduction of ``TaskResult`` was to
make an equatable-friendly version of `Result` for when the error produced was `any Error`, which is
not equatable. And the reason to want an equatable-friendly result is so that the `Action` type in
reducers can be equatable, and the reason for _that_ is to make it possible to test actions
emitted by effects.

Typically in tests, when one wants to assert that the ``TestStore`` received an action you must 
specify a concrete action:

```swift
store.receive(.response(.success("Hello!"))) {
  // ...
}
```

The ``TestStore`` uses the equatable conformance of `Action` to confirm that you are asserting that
the store received the correct action.

However, this becomes verbose when testing deeply nested features, which is common in integration
tests:

```swift
store.receive(.child(.response(.success("Hello!")))) {
  // ...
}
```

However, with the introduction of [case key paths][swift-case-paths] we greatly improved the 
ergonomics of referring to deeply nested enums. You can now use key path syntax to describe the 
case of the enum you expect to receive, and you can even omit the associated data from the action
since typically that is covered in the state assertion:

```swift
store.receive(\.child.response.success) {
  // ...
}
```

And this syntax does not require the `Action` enum to be equatable since we are only asserting that
the case of the action was received. We are not testing the data in the action.

We feel that with this better syntax there is less of a reason to have ``TaskResult`` and so we
do plan on removing it eventually. If you have an important use case for ``TaskResult`` that you
think merits it being in the library, please [open a discussion][tca-discussions].

### Identified actions

In version 1.4 of the library we introduced the ``IdentifiedAction`` type which makes it more
ergonomic to bundle the data needed for actions in collections of data. Previously you would
have a case in your `Action` enum for a particular row that holds the ID of the state being acted
upon as well as the action:

```swift
enum Action {
  // ...
  case row(id: State.ID, action: Action)
}
```

This can be updated to hold onto ``IdentifiedAction`` instead of those piece of data directly in the 
case:

```swift
enum Action {
  // ...
  case rows(IdentifiedActionOf<Nested>)
}
```

And in the reducer, instead of invoking ``Reducer/forEach(_:action:element:fileID:line:)-65nr1``
with a case path using the `/` prefix operator:

```swift
Reduce { state, action in 
  // ...
}
.forEach(\.rows, action: /Action.row(id:action:)) {
  RowFeature()
}
```

…you will instead use key path syntax to determine which case of the `Action` enum holds the
identified action:

```swift
Reduce { state, action in 
  // ...
}
.forEach(\.rows, action: \.rows) {
  RowFeature()
}
```

This syntax is shorter, more familiar, and can better leverage Xcode autocomplete and 
type-inference.

One last change you will need to make is anywhere you are destructuring the old-style action you 
will need to insert a `.element` layer:

```diff
-case let .row(id: id, action: .buttonTapped):
+case let .rows(.element(id: id, action: .buttonTapped)):
```

[swift-case-paths]: http://github.com/pointfreeco/swift-case-paths
[tca-discussions]: http://github.com/pointfreeco/swift-composable-architecture/discussions
