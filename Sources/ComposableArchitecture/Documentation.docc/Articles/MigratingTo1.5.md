# Migrating to 1.5

Update your code to make use of the new ``Store/scope(state:action:)-90255`` operation on ``Store``
in order to improve the performance of your features and simplify the usage of navigation APIs.

## Overview

The Composable Architecture is under constant development, and we are always looking for ways to
simplify the library, and make it more powerful. As such, we often need to deprecate certain APIs
in favor of newer ones. We recommend people update their code as quickly as possible to the newest
APIs, and this article contains some tips for doing so.

> Important: Many APIs have been soft-deprecated in this release and will be hard-deprecated in
a future minor release. We highly recommend updating your use of deprecated APIs to their newest
version as quickly as possible.

* [Store scoping with key paths](#Store-scoping-with-key-paths)
* [Scoping performance](#Scoping-performance)
* [Enum-driven navigation APIs](#Enum-driven-navigation-APIs)

### Store scoping with key paths

Prior to version 1.5 of the Composable Architecture, one was allowed to
``ComposableArchitecture/Store/scope(state:action:)-9iai9`` a store with any kind of closures that
transform the parent state to the child state, and child actions into parent actions:

```swift
store.scope(
  state: (State) -> ChildState,
  action: (ChildAction) -> Action
)
```

In practice you could typically use key paths for the `state` transformation since key path literals
can be promoted to closures. That means often scoping looked something like this:

```swift
// ⚠️ Deprecated API
ChildView(
  store: self.store.scope(
    state: \.child, 
    action: { .child($0) }
  )
)
```

However, as of version 1.5 of the Composable Architecture, the version of 
``ComposableArchitecture/Store/scope(state:action:)-9iai9`` that takes two closures is 
**soft-deprecated**. Instead, you are to use the version of 
``ComposableArchitecture/Store/scope(state:action:)-90255`` that takes a key path for the `state` 
argument, and a case key path for the `action` argument.

This is easiest to do when you are using the ``ComposableArchitecture/Reducer()`` macro with your
feature because then case key paths are automatically generated for each case of your action enum.
The above construction of `ChildView` now becomes:

```swift
// ✅ New API
ChildView(
  store: self.store.scope(
    state: \.child, 
    action: \.child
  )
)
```

The syntax is now shorter and more symmetric, and there is a hidden benefit too. Because key paths
are `Hashable`, we are able to cache the store created by `scope`. This means if the store is scoped
again with the same `state` and `action` arguments, we can skip creating a new store and instead 
return the previously created one. This provides a lot of benefits, such as better performance, and
a stable identity for features.

There are some times when changing to this new scoping operator may be difficult. For example, if
you perform additional work in your scoping closure so that a simple key path does not work:

```swift
ChildView(
  store: self.store.scope(
    state: { ChildFeature(state: $0.child) }, 
    action: { .child($0) }
  )
)
```

This can be handled by moving the work in the closure to a computed property on your state:

```swift
extension State {
  var childFeature: ChildFeature {
    ChildFeature(state: self.child) 
  }
}
```

And now the key path syntax works just fine:

```swift
ChildView(
  store: self.store.scope(
    state: \.childFeature, 
    action: \.child
  )
)
```

Another complication is if you are using data from _outside_ the closure, _inside_ the closure:

```swift
ChildView(
  store: self.store.scope(
    state: { 
      ChildFeature(
        settings: viewStore.settings,
        state: $0.child
      ) 
    }, 
    action: { .child($0) }
  )
)
```

In this situation you can add a subscript to your state so that you can pass that data into it:

```swift
extension State {
  subscript(settings settings: Settings) -> ChildFeature {
    ChildFeature(
      settings: settings,
      state: self.child
    )
  }
}
```

Then you can use a subscript key path to perform the scoping:

```swift
ChildView(
  store: self.store.scope(
    state: \.[settings: viewStore.settings], 
    action: \.child
  )
)
```

Another common case you may encounter is when dealing with collections. It is common in the 
Composable Architecture to use an `IdentifiedArray` in your feature's state and an
``IdentifiedAction`` in your feature's actions (see <doc:MigratingTo1.4#Identified-actions> for more
info on ``IdentifiedAction``). If you needed to scope your store down to one specific row of the
identified domain, previously you would have done so like this:

```swift
store.scope(
  state: \.rows[id: id],
  action: { .rows(.element(id: id, action: $0)) }
)
```

With case key paths it can be done simply like this:

```swift
store.scope(
  state: \.rows[id: id],
  action: \.rows[id: id]
)
```

These tricks should be enough for you to rewrite all of your store scopes using key paths, but if
you have any problems feel free to open a
[discussion](http://github.com/pointfreeco/swift-composable-architecture/discussions) on the repo.

## Scoping performance

The performance characteristics for store scoping have changed in this release. The primary (and
intended) way of scoping is along _stored_ properties of child features. A very basic example of this
is the following:

```swift
ChildView(
  store: store.scope(state: \.child, action: \.child)
)
```

A less common (and less supported) form of scoping is along _computed_ properties, for example like
this:

```swift
extension ParentFeature.State {
  var computedChild: ChildFeature.State {
    ChildFeature.State(
      // Heavy computation here...
    )
  }
}

ChildView(
  store: store.scope(state: \.computedChild, action: \.child)
)
```

This style of scoping will incur a bit of a performance cost in 1.5 and moving forward. The cost
is greater the closer your scoping is to the root of your application. Leaf node features will not
incur as much of a cost.

See the dedicated article <doc:Performance#Store-scoping> for more information.

## Enum-driven navigation APIs

Prior to version 1.5 of the library, using enum state with navigation view modifiers, such as 
`sheet`, `popover`, `navigationDestination`, etc, was quite verbose. You first needed to supply a 
store scoped to the destination domain, and then further provide transformations for isolating the
case of the state enum to drive the navigation, as well as a transformation for embedding child 
actions back into the destination domain:

```swift
// ⚠️ Deprecated API
.sheet(
  store: self.store.scope(state: \.$destination, action: { .destination($0) }),
  state: \.editForm,
  action: { .editForm($0) }
)
```

The navigation view modifiers that take `store`, `state` and `action` arguments are now deprecated,
and instead you can do it all with a single `store` argument:

```swift
// ✅ New API
.sheet(
  store: self.store.scope(
    state: \.$destination.editForm, 
    action: \.destination.editForm
  )
)
```

All navigation APIs that take 3 arguments for the `store`, `state` and `action` have been
**soft-deprecated** and instead you should make use of the version of the APIs that take a single
`store` argument. This includes:

* `alert(store:state:action:)`
* `confirmationDialog(store:state:action:)`
* `fullScreenCover(store:state:action:)`
* `navigationDestination(store:state:action)`
* `popover(store:state:action:)` 
* `sheet(store:state:action:)`
* ``IfLetStore``.``IfLetStore/init(_:state:action:then:)``
* ``IfLetStore``.``IfLetStore/init(_:state:action:then:else:)``

