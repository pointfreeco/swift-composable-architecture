# Navigation

Learn how to use the navigation tools in the library, including how to best model your domains,
how to integrate features in the reducer and view layer, and how to write tests.

## Overview

State-driven navigation is a powerful concept in application development, but can be tricky to 
master. The Composable Architecture provides the tools necessary to model your domains as concisely
as possible and drive navigation from state, but there are a few concepts to learn in order to best
yield these tools.

## What is navigation?

The word "navigation" can mean a lot of different things to different people. For example, most
people would agree that the drill-down style of navigation afforded to us by `NavigationStack` in
SwiftUI and `UINavigationController` in UIKit. However, if drill-downs are considered navigation,
then surely sheets and fullscreen covers should be too. The only difference is that sheets and 
covers animate from bottom-to-top instead of from right-to-left, but is that actually 
substantive?

And if sheets and covers are considered navigation, then certainly popovers should be too. We can
even expand our horizons to include more styles of navigation, such as alerts and 
confirmation dialogs, and even custom forms of navigation that are not handed down to us from Apple.

So, for the purposes of this documentation, we will use the following loose definition of 
"navigation":

> Defintion: **Navigation**: A change of mode in the application.

Each of the examples we considered above, such as drill-downs, sheets, popovers, covers, alerts, 
and more, are all a "change of mode" in the application.

But, we will further refine the concept of "change of mode" to mean that some piece of state went
from not existing to existing, or vice-versa. So, when a piece of state switches from not existing
to existing, that represents a navigation to a mode of the application, and when the state switches
back to not existing, it represents undoing the navigation and returning to the previous mode.

That is very abstract way of describing state-driven navigation, and the next two sections make
these concepts much more concrete for the two main forms of navigation: 
 [tree-based](#Tree-based-navigation) and [stack-based](#Stack-based-navigation) navigation.

## Tree-based navigation

In the previous section we defined state-driven navigation as being controlled by the existence
or non-existence of state. The term "existence" was not defined, and there are a few ways in which
existence can be defined. If we define the existence or non-existence of state as being 
represented by a Swift `Optional` type, then we cause this "tree-based" navigation because
when multiple states of navigation are nested they form a tree-like structure.

For example, suppose you have an inventory feature with a list of items such that tapping one
of those items performs a drill-down navigation to a detail screen for the item. Then that can
be modeled with the ``PresentationState`` property wrapper pointing to some optional state:

```swift
struct InventoryFeature: ReducerProtocol {
  struct State {
    @PresentationState var detailItem: DetailItemFeature.State?
    // ...
  }
  // ...
}
```

Then, inside that detail screen there may be a button to edit the item in a sheet, and that too
can be modeled with a ``PresentationState`` property wrapper pointing to a piece of optional 
state:

```swift
struct DetailItemFeature: ReducerProtocol {
  struct State {
    @PresentationState var editItem: EditItemFeature.State?
    // ...
  }
  // ...
}

struct EditItemFeature: ReducerProtocol {
  struct State {
    var item: Item
    // ...
  }
  // ...
}
```

Then the act of deep-linking the application into a state where we are drilled down to a particular
item _with_ the edit sheet opened, we simply need to construct a deeply nested piece of state
that represents the navigation:

```swift
InventoryView(
  store: Store(
    initialState: InventoryFeature.State(
      detailItem: DetailItemFeature.State(
        editItem: EditItemFeature.State(
          item: Item(name: "Headphones", quantity: 10)
        )
      )
    ),
    reducer: InventoryFeature()
  )
)
```

In the above we can start to see the tree-like structure of this form of domain modeling. Each 
feature in your application represents a node of the tree, and each destination you can navigate
to represents a branch from the node. Then the act of navigating to a new feature corresponds
to building another nested piece of state.

That is the basics of tree-based navigation, but now you must read the dedicated 
<doc:TreeBasedNavigation> article for information on how to use the tools that come with the 
Composable Architecture to implement tree-based navigation in your application.

## Stack-based navigation

In the [previous section](#Tree-based-navigation) we defined "tree-based" navigation as the process
of modeling the presentation of a child feature with optional state. This takes on a tree-like
structure in which a deeply nested feature is represented by a deeply nested piece of state.

There is another powerful tool for modeling the existence and non-existence of state for driving
navigation: collections. This is most used with SwiftUI's `NavigationStack` view in which an
entire stack of features are represented by a collection of data. When an item is added to the 
collection it represents a new feature being pushed onto the stack, and when an item is removed
from the collection it represents popping the feature off the stack.

Typically one defines an enum that holds all of the possible features that can be navigated to
on the stack, so continuing the analogy from the previous section, if an inventory list can 
navigate to a detail feature for an item and then navigate to an edit screen, this can be 
represented by:

```swift
enum Path {
  case detail(DetailItemFeature.State)
  case edit(DetailItemFeature.State)
  // …
}
```

Then a collection of these states represents the features that are presented on the stack:

```swift
let path: [Path] = [
  .detail(DetailItemFeature.State(item: item)),
  .edit(EditItemFeature.State(item: item)),
  // …
]
```

That is the basics of stack-based navigation, but now you must read the dedicated 
<doc:StackBasedNavigation> article for information on how to use the tools that come with the 
Composable Architecture to implement stack-based navigation in your application.

## Tree-based vs stack-based navigation

Most 

## Topics

### Types of navigation

- <doc:TreeBasedNavigation>
- <doc:StackBasedNavigation>


