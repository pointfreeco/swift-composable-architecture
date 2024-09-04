# What is navigation?

Learn about the two main forms of state-driven navigation, tree-based and stack-based navigation, 
as well as their tradeoffs.

## Overview

State-driven navigation broadly falls into 2 main categories: tree-based, where you use optionals
and enums to model navigation, and stack-based, where you use flat collections to model navigation.
Nearly all navigations will use a combination of the two styles, but it is important to know
their strengths and weaknesses.

* [Tree-based navigation](#Tree-based-navigation)
* [Stack-based navigation](#Stack-based-navigation)
* [Tree-based vs stack-based navigation](#Tree-based-vs-stack-based-navigation)
  * [Pros of tree-based navigation](#Pros-of-tree-based-navigation)
  * [Cons of tree-based navigation](#Cons-of-tree-based-navigation)
  * [Pros of stack-based navigation](#Pros-of-stack-based-navigation)
  * [Cons of stack-based navigation](#Cons-of-stack-based-navigation)


## Defining navigation

The word "navigation" can mean a lot of different things to different people. For example, most
people would say that an example of "navigation" is the drill-down style of navigation afforded to 
us by `NavigationStack` in SwiftUI and `UINavigationController` in UIKit "navigation". 
However, if drill-downs are considered navigation, then surely sheets and fullscreen covers should 
be too.  The only difference is that sheets and covers animate from bottom-to-top instead of from 
right-to-left, but is that actually substantive?

And if sheets and covers are considered navigation, then certainly popovers should be too. We can
even expand our horizons to include more styles of navigation, such as alerts and confirmation
dialogs, and even custom forms of navigation that are not handed down to us from Apple.

So, for the purposes of this documentation, we will use the following loose definition of 
"navigation":

> Definition: **Navigation** is a change of mode in the application.

Each of the examples we considered above, such as drill-downs, sheets, popovers, covers, alerts, 
dialogs, and more, are all a "change of mode" in the application.

But, so far we have just defined one term, "navigation", by using another undefined term, 
"change of mode", so we will further make the following definition:

> Definition: A **change of mode** is when some piece of state goes from not existing to existing,
or vice-versa.

So, when a piece of state switches from not existing to existing, that represents a navigation and 
change of mode in the application, and when the state switches back to not existing, it represents 
undoing the navigation and returning to the previous mode.

That is very abstract way of describing state-driven navigation, and the next two sections make
these concepts much more concrete for the two main forms of state-driven navigation:
[tree-based](#Tree-based-navigation) and [stack-based](#Stack-based-navigation) navigation.

## Tree-based navigation

In the previous section we defined state-driven navigation as being controlled by the existence or
non-existence of state. The term "existence" was not defined, and there are a few ways in which
existence can be defined. If we define the existence or non-existence of state as being represented
by Swift's `Optional` type, then we call this "tree-based" navigation because when multiple states
of navigation are nested they form a tree-like structure.

For example, suppose you have an inventory feature with a list of items such that tapping one of
those items performs a drill-down navigation to a detail screen for the item. Then that can be
modeled with the ``Presents()`` macro pointing to some optional state:

```swift
@Reducer
struct InventoryFeature {
  @ObservableState
  struct State {
    @Presents var detailItem: DetailItemFeature.State?
    // ...
  }
  // ...
}
```

Then, inside that detail screen there may be a button to edit the item in a sheet, and that too can
be modeled with the ``Presents()`` macro pointing to a piece of optional state:

```swift
@Reducer
struct DetailItemFeature {
  @ObservableState
  struct State {
    @Presents var editItem: EditItemFeature.State?
    // ...
  }
  // ...
}
```

And further, inside the "edit item" feature there can be a piece of optional state that represents
whether or not an alert is displayed:

```swift
@Reducer
struct EditItemFeature {
  struct State {
    @Presents var alert: AlertState<AlertAction>?
    // ...
  }
  // ...
}
```

And this can continue on and on for as many layers of navigation that exist in the application.

With that done, the act of deep-linking into the application is a mere exercise in constructing
a piece of deeply nested state. So, if we wanted to launch the inventory view into a state where
we are drilled down to a particular item _with_ the edit sheet opened _and_ an alert opened, we 
simply need to construct the piece of state that represents the navigation:

```swift
InventoryView(
  store: Store(
    initialState: InventoryFeature.State(
      detailItem: DetailItemFeature.State(      // Drill-down to detail screen
        editItem: EditItemFeature.State(        // Open edit modal
          alert: AlertState {                   // Open alert
            TextState("This item is invalid.")
          }
        )
      )
    )
  ) {
    InventoryFeature()
  }
)
```

In the above we can start to see the tree-like structure of this form of domain modeling. Each 
feature in your application represents a node of the tree, and each destination you can navigate to
represents a branch from the node. Then the act of navigating to a new feature corresponds to
building another nested piece of state.

That is the basics of tree-based navigation. Read the dedicated <doc:TreeBasedNavigation> article
for information on how to use the tools that come with the Composable Architecture to implement
tree-based navigation in your application.

## Stack-based navigation

In the [previous section](#Tree-based-navigation) we defined "tree-based" navigation as the process
of modeling the presentation of a child feature with optional state. This takes on a tree-like
structure in which a deeply nested feature is represented by a deeply nested piece of state.

There is another powerful tool for modeling the existence and non-existence of state for driving
navigation: collections. This is most used with SwiftUI's `NavigationStack` view in which 
an entire stack of features are represented by a collection of data. When an item is added to the 
collection it represents a new feature being pushed onto the stack, and when an item is removed from 
the collection it represents popping the feature off the stack.

Typically one defines an enum that holds all of the possible features that can be navigated to on
the stack, so continuing the analogy from the previous section, if an inventory list can navigate to
a detail feature for an item and then navigate to an edit screen, this can be represented by:

```swift
enum Path {
  case detail(DetailItemFeature.State)
  case edit(EditItemFeature.State)
  // ...
}
```

Then a collection of these states represents the features that are presented on the stack:

```swift
let path: [Path] = [
  .detail(DetailItemFeature.State(item: item)),
  .edit(EditItemFeature.State(item: item)),
  // ...
]
```

This collection of `Path` elements can be any length necessary, including very long to represent
being drilled down many layers deep, or even empty to represent that we are at the root of the 
stack.

That is the basics of stack-based navigation. Read the dedicated 
<doc:StackBasedNavigation> article for information on how to use the tools that come with the 
Composable Architecture to implement stack-based navigation in your application.

## Tree-based vs stack-based navigation

Most real-world applications will use a mixture of tree-based and stack-based navigation. For
example, the root of your application may use stack-based navigation with a 
`NavigationStack` view, but then each feature inside the stack may use tree-based 
navigation for showing sheets, popovers, alerts, etc. But, there are pros and cons to each form of 
navigation, and so it can be important to be aware of their differences when modeling your domains.

#### Pros of tree-based navigation

  * Tree-based navigation is a very concise way of modeling navigation. You get to statically 
    describe all of the various navigation paths that are valid for your application, and that makes
    it impossible to restore a navigation that is invalid for your application. For example, if it
    only makes sense to navigate to an "edit" screen after a "detail" screen, then your detail
    feature needs only to hold onto a piece of optional edit state:

    ```swift
    @ObservableState
    struct State {
      @Presents var editItem: EditItemFeature.State?
      // ...
    }
    ```

    This statically enforces the relationship that we can only navigate to the edit screen from the
    detail screen.

  * Related to the previous pro, tree-based navigation also allows you to describe the finite number
    of navigation paths that your app supports.

  * If you modularize the features of your application, then those feature modules will be more
    self-contained when built with the tools of tree-based navigation. This means that Xcode
    previews and preview apps built for the feature will be fully functional.

    For example, if you have a `DetailFeature` module that holds all of the logic and views for the
    detail feature, then you will be able to navigate to the edit feature in previews because the
    edit feature's domain is directly embedded in the detail feature.

  * Related to the previous pro, because features are tightly integrated together it makes writing
    unit tests for their integration very simple. You can write deep and nuanced tests that assert 
    how the detail feature and edit feature integrate together, allowing you to prove that they
    interact in the correct way.

  * Tree-based navigation unifies all forms of navigation into a single, concise style of API, 
    including drill-downs, sheets, popovers, covers, alerts, dialogs and a lot more. See
    <doc:TreeBasedNavigation#API-Unification> for more information.

#### Cons of tree-based navigation

  * Unfortunately it can be cumbersome to express complex or recursive navigation paths using
    tree-based navigation. For example, in a movie application you can navigate to a movie, then a
    list of actors in the movies, then to a particular actor, and then to the same movie you started
    at. This creates a recursive dependency between features that can be difficult to model in Swift
    data types.

  * By design, tree-based navigation couples features together. If you can navigate to an edit
    feature from a detail feature, then you must be able to compile the entire edit feature in order
    to compile the detail feature. This can eventually slow down compile times, especially when you
    work on features closer to the root of the application since you must build all destination
    features.

  * Historically, tree-based navigation is more susceptible to SwiftUI's navigation bugs, in 
    particular when dealing with drill-down navigation. However, many of these bugs have been fixed
    in iOS 16.4 and so is less of a concern these days.

#### Pros of stack-based navigation

  * Stack-based navigation can easily handle complex and recursive navigation paths. The example we
    considered earlier, that of navigating through movies and actors, is handily accomplished with
    an array of feature states:

    ```swift
    let path: [Path] = [
      .movie(/* ... */),
      .actors(/* ... */),
      .actor(/* ... */),
      .movies(/* ... */),
      .movie(/* ... */),
    ]
    ```

    Notice that we start on the movie feature and end on the movie feature. There is no real 
recursion in this navigation since it is just a flat array.

* Each feature held in the stack can typically be fully decoupled from all other screens on the
stack. This means the features can be put into their own modules with no dependencies on each
other, and can be compiled without compiling any other features.

* The `NavigationStack` API in SwiftUI typically has fewer bugs than 
`NavigationLink(isActive:)` and `navigationDestination(isPresented:)`, which are used in tree-based 
navigation. There are still a few bugs in `NavigationStack`, but on average it is a lot 
more stable.

#### Cons of stack-based navigation

  * Stack-based navigation is not a concise tool. It makes it possible to express navigation
    paths that are completely non-sensical. For example, even though it only makes sense to navigate
    to an edit screen from a detail screen, in a stack it would be possible to present the features
    in the reverse order:

    ```swift
    let path: [Path] = [
      .edit(/* ... */),
      .detail(/* ... */)
    ]
    ```
  
    That is completely non-sensical. What does it mean to drill down to an edit screen and _then_
    a detail screen. You can create other non-sensical navigation paths, such as multiple edit
    screens pushed on one after another:
  
    ```swift
    let path: [Path] = [
      .edit(/* ... */),
      .edit(/* ... */),
      .edit(/* ... */),
    ]
    ```
  
    This too is completely non-sensical, and it is a drawback to the stack-based approach when you 
    want a finite number of well-defined navigation paths in your app.

  * If you were to modularize your application and put each feature in its own module, then those
    features, when run in isolation in an Xcode preview, would be mostly inert. For example, a
    button in the detail feature for drilling down to the edit feature can't possibly work in an
    Xcode preview since the detail and edit features have been completely decoupled. This makes it
    so that you cannot test all of the functionality of the detail feature in an Xcode preview, and
    instead have to resort to compiling and running the full application in order to preview
    everything.

  * Related to the above, it is also more difficult to unit test how multiple features integrate
    with each other. Because features are fully decoupled we cannot easily test how the detail and
    edit feature interact with each other. The only way to write that test is to compile and run the
    entire application.

  * And finally, stack-based navigation and `NavigationStack` only applies to drill-downs 
    and does not address at all other forms of navigation, such as sheets, popovers, alerts, etc. 
    It's still on you to do the work to decouple those kinds of navigations.

---

We have now defined the basic terms of navigation, in particular state-driven navigation, and we
have further divided navigation into two categories: tree-based and stack-based. Continue reading
the dedicated articles <doc:TreeBasedNavigation> and <doc:StackBasedNavigation> to learn about the 
tools the Composable Architecture provides for modeling your domains and integrating features 
together for navigation.
