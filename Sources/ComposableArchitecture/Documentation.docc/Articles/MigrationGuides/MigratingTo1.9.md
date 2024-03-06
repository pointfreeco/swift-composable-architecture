# Migrating to 1.9

Update your code to make use of the new ``TestStore/send(_:assert:file:line:)-1oopl`` method on 
``TestStore`` which gives a succinct syntax for sending actions with case key paths, and the
``Reducer/dependency(_:)`` method for overriding dependencies.

## Overview

The Composable Architecture is under constant development, and we are always looking for ways to
simplify the library, and make it more powerful. As such, we often need to deprecate certain APIs
in favor of newer ones. We recommend people update their code as quickly as possible to the newest
APIs, and this article contains some tips for doing so.

### Sending test store actions

Version 1.4 of the library introduced the ability to receive test store actions using case key path
syntax, massively simplifying how one asserts on actions received in a test:

```diff
-store.receive(.child(.presented(.response(.success("Hello")))))
+store.receive(\.child.response.success)
```

While version 1.6 of the library introduced the ability to assert against the payload of a received
action:

```swift
store.receive(\.child.presented.success, "Hello")
```

Version 1.9 introduces similar affordances for _sending_ actions to test stores via
``TestStore/send(_:assert:file:line:)-1oopl`` and ``TestStore/send(_:_:assert:file:line:)``. These
methods can significantly simplify integration-style tests that send deeply-nested actions to child
features, and provide symmetry to how actions are received:

```diff
-store.send(.path(.element(id: 0, action: .destination(.presented(.record(.startButtonTapped))))))
+store.send(\.path[id: 0].destination.record.startButtonTapped)
 store.receive(\.path[id: 0].destination.record.timerTick)
```

> Tip: Case key paths offer specialized syntax for many different action types.
>
>   * ``PresentationAction``'s `presented` case can be collapsed:
>
>     ```diff
>     -store.send(.destination(.presented(.tap)))
>     +store.send(\.destination.tap)
>     ```
>
>   * ``IdentifiedAction`` and ``StackAction`` can be subscripted into:
>
>     ```diff
>     -store.send(.path(.element(id: 0, action: .tap)))
>     +store.send(\.path[id: 0].tap)
>     ```
>
>   * And ``BindingAction``s can dynamically chain into a key path of state:
>
>     ```diff
>     -store.send(.binding(.set(\.firstName, "Blob")))
>     +store.send(\.binding.firstName, "Blob")
>     ```
>
> Together, these helpers can massively simplify asserting against nested actions:
>
> ```diff
> -store.send(
> -  .path(
> -    .element(
> -      id: 0,
> -      action: .destination(
> -        .presented(
> -          .sheet(
> -            .binding(
> -              .set(\.password, "blobisawesome")
> -            )
> -          )
> -        )
> -      )
> -    )
> -  )
> -)
> +store.send(\.path[id: 0].destination.sheet.binding.password, "blobisawesome")
> ```

### Overriding dependencies

Version 1.2 of [swift-dependencies](http://github.com/pointfreeco/swift-dependencies) introduced an
alternative syntax for referencing a dependency:

```diff
-@Dependency(\.apiClient) var apiClient
+@Dependency(APIClient.self) var apiClient
```

The primary benefit of this syntax is that you do not need to define a dedicated computed property
on `DependencyValues`, which saves a small amount of boilerplate.

There is now a similar API for overriding dependencies on a reducer, ``Reducer/dependency(_:)``, 
which can be used like so:

```swift
MyFeature()
  .dependency(mockAPIClient)
```

The type of `mockAPIClient` determines how the dependency is overridden.

This style of accessing and overriding dependencies is really only appropriate for dependencies
defined directly in your project. If you are shipping a dependency client that is used by others, 
then still prefer adding a computed property to `DependencyValues` in order to be more discoverable.
