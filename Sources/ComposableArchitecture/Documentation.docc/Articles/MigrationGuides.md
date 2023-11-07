# Migration Guides

Learn how to update your code to use the newest tools of the library as it evolves.

## Overview

The Composable Architecture is under constant development, and we are always looking for ways to
simplify the library, and make it more powerful. As such, we often need to deprecate certain APIs
in favor of newer ones. We recommend people update their code as quickly as possible to the newest
APIs, and this article contains some tips for doing so.

* [Store scoping with key paths](#Store-scoping-with-key-paths)
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
ChildView(
  store: self.store.scope(
    state: \.child, 
    action: { .child($0) }
  )
)
```

However, as of 1.5 of the Composable Architecture, the version of 
``ComposableArchitecture/Store/scope(state:action:)-9iai9`` that takes two closures is deprecated.
Instead, you are to use the version of ``ComposableArchitecture/Store/scope(state:action:)-90255``
that takes a key path for the `state` argument, and a case key path for the `action` argument.

This is easiest to do when you are using the ``ComposableArchitecture/Reducer()`` macro with your
feature because then case key paths are automatically generated for each case of your action enum.
The above construction of `ChildView` now becomes:

```swift
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

These tricks should be enough for you to rewrite all of your store scopes using key paths, but if
you have any problems feel free to open a
[discussion](http://github.com/pointfreeco/swift-composable-architecture/discussions) on the repo.

## Enum-driven navigation APIs

Prior to version 1.5 of the library, using enum state with navigation view modifiers, such as 
`sheet`, `popover`, `navigationDestination`, etc, was quite verbose. You first needed to supply a 
store scoped to the destination domain, and then further provide transformations for isolating the
case of the state enum to drive the navigation, as well as a transformation for embedding child 
actions back into the destination domain:

```swift
.sheet(
  store: self.store.scope(state: \.$destination, action: { .destination($0) }),
  state: \.editForm,
  action: { .editForm($0) }
)
```

The navigation view modifiers that take `store`, `state` and `action` arguments are now deprecated,
and instead you can do it all with a single `store` argument:

```swift
.sheet(
  store: self.store.scope(state: \.$destination.editForm, action: \.destination.editForm)
)
```
