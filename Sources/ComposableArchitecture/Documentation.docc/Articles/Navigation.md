# Navigation

Learn how to use the navigation tools in the library, including how to best model your domains,
how to integrate features in the reducer and view layer, and how to write tests.

## Overview

State-driven navigation is a powerful concept in application development, but can be tricky to 
master. The Composable Architecture provides the tools necessary to model your domains as concisely
as possible and drive navigation from state, but there are a few concepts to learn in order to best
yield these tools.

## Tree-based vs stack-based navigation

There are two main

## Topics

### Types of navigation

- <doc:TreeBasedNavigation>
- <doc:StackBasedNavigation>



<!--
## Integrating features for navigation

The process for integrating features together for navigation largely consists of 2 steps: 
integrating the features' domains together and integrating the features' views together.
One typically starts by integrating the features' domains together. This consists of adding the
child's state and actions to the parent, and then utilizing a reducer operator to compose the
child reducer into the parent.

For example, suppose you have a list of items and you want to be able to show a sheet to display
a form for adding a new item. We can integrate state and actions together by utilizing the 
``PresentationState`` and ``PresentationAction`` types:

```swift
struct InventoryFeature: ReducerProtocol {
  struct State: Equatable {
    @PresentationState var addItem: ItemFormFeature.State?
    var items: IdentifiedArrayOf<Item> = []
    // ...
  }
  enum Action: Equatable {
    case addItem(PresentationAction<ItemFormFeature.Action>)
    // ...
  }
  // ...
}
``` 

> Note: The `addItem` state is held as an optional. A non-`nil` value represents that feature
is being presented, and `nil` presents the feature is dismissed.

Next you can integrate the reducers of the parent and child features by using the 
``ReducerProtocol/ifLet(_:action:then:file:fileID:line:)`` reducer operator, as well
as having an action in the parent domain for populating the child's state to drive navigation:

```swift
struct InventoryFeature: ReducerProtocol {
  struct State: Equatable { /* ... */ }
  enum Action: Equatable { /* ... */ }
  
  var body: some ReducerProtocolOf<Self> {
    Reduce<State, Action> { state, action in 
      switch action {
      case .addButtonTapped:
        state.addItem = ItemFormFeature.State()
        return .none
      // ...
      }
    }
    .ifLet(\.$addItem, action: /Action.addItem) {
      ItemFormFeature()
    }
  }
}
```

> Note: The key path used with `ifLet` focuses on the `@PresentationState` since it uses the `$`
syntax. Also note that the action uses a [case 
path](http://github.com/pointfreeco/swift-case-paths), which is analagous to key paths but tuned
for enums, and uses the forward slash syntax.

That's all that it takes to integrate the domains and logic of the parent and child features. Next
we need to integrate the features' views. This is done using view modifiers that look similar to
SwiftUI's, but are tuned specifically to work with the Composable Architecture.

For example, to show a sheet from the `addItem` state in the `InventoryFeature`, we can use
the `sheet(store:)` modifier that takes a ``Store`` as an argument that is focused on presentation
state and actions:

```swift
struct InventoryFeature: View {
  let store: StoreOf<InventoryFeature>

  var body: some View {
    List {
      // ...
    }
    .sheet(
      store: self.store.scope(state: \.$addItem, action: InventoryFeature.Action.addItem)
    )
  }
}
```

Note that we again specify a key path to the presentation state property wrapper, i.e. `\.$addItem`, 
but this time we only need to specify the case of the action, `InventoryFeature.Action.addItem`, 
and not a case path. This means there is no leading forward slash.

With those few steps completed the domains and views of the parent and child features are now
integrated together, and when the `addItem` state flips to a non-`nil` value the sheet will be
presented, and when it is `nil`'d out it will be dismissed.

The library ships with overloads for all of SwiftUI's styles of navigation that take stores of 
presentation domain, including:

* `alert(store:)`
* `confirmationDialog(store:)`
* `sheet(store:)`
* `popover(store:)`
* `fullScreenCover(store:)`
* `navigationDestination(store:)`
* ``NavigationLinkStore``

## Correctness

## Testing

## Advanced

<!-- domain modeling with enums -->
<!-- child dismiss -->

