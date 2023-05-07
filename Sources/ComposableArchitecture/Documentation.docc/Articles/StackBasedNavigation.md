# Stack-based navigation

Learn about stack-based navigation, that is navigation modeled with collections, including how to
model your domains, how to integrate features, how to test your features, and more.

## Overview

Stack-based navigation is the process of modeling navigation using collections of state. This style
of navigation allows you to deep-link into any state of your application by simply constructing a
flat collection of data, handing, handing it off to SwiftUI, and letting it take care of the rest.
It also allows for complex and recusive navigation paths in your application.

  * [Basics](#Basics)
  * [Integration](#Integration)
  * [Dismissal](#Dismissal)
  * [Testing](#Testing)
  * [StackState vs NavigationPath](#StackState-vs-NavigationPath)

## Basics

The tools for this style of navigation include ``StackState``, ``StackAction`` and the
``ReducerProtocol/forEach(_:action:destination:fileID:line:)`` operator, as well as a new 
``NavigationStackStore`` view that behaves like `NavigationStack` but is tuned specifically for the 
Composable Architecture.

The process of integrating features into a navigation stack largely consists of 2 steps: 
integrating the features' domains together, and constructing a ``NavigationStackStore`` for 
describing all the views in the stack. One typically starts by integrating the features' domains 
together. This consists of defining a new reducer, typically called `Path`, that holds the domains
of all the features that can be pushed onto the stack:

```swift
struct RootFeature: ReducerProtocol {
  // ...

  struct Path: ReducerProtocol {
    enum State {
      case addItem(AddFeature.State)
      case detailItem(DetailFeature.State)
      case editItem(EditFeature.State)
    }
    enum Action {
      case addItem(AddFeature.Action)
      case detailItem(DetailFeature.Action)
      case editItem(EditFeature.Action)
    }
    var body: some ReducerProtocolOf<Self> {
      Scope(state: /State.addItem, action: /Action.addItem) { 
        AddFeature()
      }
      Scope(state: /State.editItem, action: /Action.editItem) { 
        EditFeature()
      }
      Scope(state: /State.detailItem, action: /Action.detailItem) { 
        DetailFeature()
      }
    }
  }
}
```

> Note: The `Path` reducer is identical to the `Destination` reducer that one creates for tree-based 
> navigation when using enums. See <doc:TreeBasedNavigation#Enum-state> for more information.

Once the `Path` reducer is defined we can then hold onto ``StackState`` and ``StackAction`` in the 
feature that manages the navigation stack:

```swift
struct RootFeature: ReducerProtocol {
  struct State {
    var path = StackState<Path.State>()
    // ...
  }
  enum Action {
    case path(StackAction<Path.State, Path.Action>)
    // ...
  }
}
```

> Note: ``StackAction`` is generic over both state and action of the `Path` domain, which is in
> contrast to ``PresentationAction``, which only has a single generic.

And then we must make use of the ``ReducerProtocol/forEach(_:action:destination:fileID:line:)``
method to integrate the domains of all the features that can be navigated to with the domain of the
parent feature:

```swift
struct RootFeature: ReducerProtocol {
  // ...

  var body: some ReducerProtocolOf<Self> {
    Reduce { state, action in 
      // Core logic for root feature
    }
    .forEach(\.path, action: /Action.path) { 
      Path()
    }
  }
}
```

<!--
todo: finish
-->

## Integration

Once your features are integrated together using the steps above, your parent feature gets instant
access to everything happening inside the navigation stack. You can use this as a means to integrate
the logic of the stack element features with the parent feature. For example, if you want to detect 
when the "Save" button inside the edit feature is tapped, you can simply destructure on that action. 
This consists of pattern matching on the ``StackAction``, then the 
``StackAction/element(id:action:)`` action, then the feature you are interested in, and finally the 
action you are interested in:

```swift
case let .path(.element(id: id, action: .editItem(.saveButtonTapped))):
  // ...
```

Once inside that case you can then try extracting out the feature state so that you can perform
additional logic, such as popping the "edit" feature and saving the edited item to the database:

```swift
case let .path(.element(id: id, action: .editItem(.saveButtonTapped))):
  guard case let .editItem(editItemState) = self.path[id: id]
  else { return .none }

  state.path.pop(from: id)
  return .fireAndForget {
    self.database.save(editItemState.item)
  }
```

## Dismissal

Dismissing a feature in a stack is as simple as using mutating the ``StackState`` using one of its
methods, such as ``StackState/popLast()``, ``StackState/pop(from:)`` and more:

```swift
case .closeButtonTapped:
  state.popLast()
  return .none
```

However, in order to do this you must have access to that stack state, and usually only the parent 
has access. But often we would like to encpasulate the logic of dismissing a feature to be inside 
the child feature without needing explicit communication with the parent.

SwiftUI provides a wonderful tool for allowing child _views_ to dismiss themselves from the parent,
all without any explicit communication with the parent. It's an environment value called `dismiss`,
and it can be used like so:

```swift
struct ChildView: View {
  @Environment(\.dismiss) var dismiss
  var body: some View {
    Button("Close") {
      self.dismiss()
    }
  }
}
```

When `self.dismiss()` is invoked, SwiftUI finds the closet parent view with a presentation, and
causes it to dismiss. This can be incredibly useful, but it is also relegated to the view layer. It
is not possible to use `dismiss` elsewhere, like in an observable object.

The Composable Architecture has a similar tool, except it is appropriate to use from a reducer,
where the rest of your feature's logic and behavior resides. It is accessed via the library's
dependency management system (see <doc:DependencyManagement>) using ``DismissEffect``:

```swift
struct Feature: ReducerProtocol {
  struct State { /* ... */ }
  enum Action { 
    case closeButtonTapped
    // …
  }
  @Dependency(\.dismiss) var dismiss
  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .closeButtonTapped:
      return .fireAndForget { await self.dismiss() }
    } 
  }
}
```

> Note: The ``DismissEffect`` function is async which means it cannot be invoked directly inside a 
> reducer. Instead it must be called from either 
> ``EffectPublisher/run(priority:operation:catch:fileID:line:)`` or
> ``EffectPublisher/fireAndForget(priority:_:)``.

When `self.dismiss()` is invoked it will pop the feature off the navigation stack. This allows you 
to encapsulate the logic for dismissing a child feature entirely inside the child domain without 
explicitly communicating with the parent.

> Warning: SwiftUI's environment value `@Environment(\.dismiss)` and the Composable Architecture's
> dependency value `@Dependency(\.dismiss)` serve similar purposes, but are completely different 
> types. SwiftUI's environment value can only be used in SwiftUI views, and this library's
> dependency value can only be used inside reducers.

## Testing

<!--
todo: finish
-->

## StackState vs NavigationPath

SwiftUI comes with a powerful type for modeling data in navigation stacks called 
[`NavigationPath`][nav-path-docs], and so you might wonder why we created our own data type, 
``StackState``, instead of leverating `NavigationPath`.

The `NavigationPath` data type is a type-erased list of data that is tuned specifically for
`NavigationStack`s. It allows you to maximally decouple features in the stack since you can add any
kind of data to a path:

```swift
var path = NavigationPath()
path.append(1)
path.append("Hello")
path.append(false)
```

And SwiftUI interprets that data by describing what view should be pushed onto the stack 
corresponding to a type of data:

```swift
struct RootView: View {
  var body: some View {
    NavigationStack {
      Form {
        // ...
      }
      .navigationDestination(for: Int.self) { integer in 
        // ...
      }
      .navigationDestination(for: String.self) { string in 
        // ...
      }
      .navigationDestination(for: Bool.self) { bool in 
        // ...
      }
    }
  }
}
```

This can be powerful, but it does come with some downsides. Because the underlying data is 
type-erased, SwiftUI has decided to not expose much API on the data type. For example, the only
things you can do with a path are append data to the end of it, as seen above, or remove data
from the end of it:

```swift
path.removeLast()
```

Or count the elements in the path:

```swift
path.count
```

And that is all. You can't insert or remove elements from anywhere but the end, and you can't even
iterate over the path:

```swift
for element in path {  // 🛑
}
```

This can make it very difficult to analyze what is on the stack and aggregate data across the 
entire stack.

<!--
TODO: finishs 
-->

[nav-path-docs]: todo
