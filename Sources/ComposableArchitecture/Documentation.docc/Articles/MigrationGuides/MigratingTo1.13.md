# Migrating to 1.13

The Composable Architecture now provides first class tools for building features in UIKit, 
including minimal state observation, presentation and stack navigation.

## Overview

The Composable Architecture is now integrated with the [Swift Navigation][swift-nav-gh] library, 
which brings powerful navigation and observation tools to UIKit. You can model your domains
as concisely as possible, just as you would in SwiftUI, but then implement your view in UIKit 
without losing any power.

The simplest tool to use is `observe`, which allows you to minimally observe changes to state in
your feature and update the UI. Typically the best place to do this is in `viewDidLoad`:

```swift
let store: StoreOf<Feature>

func viewDidLoad() {
  super.viewDidLoad()

  // ...

  observe { [weak self] in
    countLabel.text = "Count: \(store.count)"
  }
}
```

Only the state accessed in the `observe` trailing closure will be observed. If any other state 
changes, the closure will not be invoked and no extra work will be performed.

The library also provides powerful navigation tools for UIKit. For example, suppose you have a
feature that can present a child feature (see the docs on [tree-based
navigation](<doc:TreeBasedNavigation>) for more information on these tools):

```swift
@Reducer 
struct Feature {
  @ObservableState
  struct State {
    @Presents var child: ChildFeature.State?
    // ...
  }
  // ...
}
```

Then you can present a view controller when the child state flips to a non-`nil` value by using the
`present(item:)` API that comes with the library:

```swift
@UIBindable var store: StoreOf<Feature>

func viewDidLoad() {
  super.viewDidLoad()

  present(item: $store.scope(state: \.child, action: \.child)) { store in
    ChildViewController(store: store)
  }
}
```

Further, if your feature has a stack of features that can be presented, then you can model your
domain like so (see the docs on [stack-based](<doc:StackBasedNavigation>) for more information
on these tools):

```swift
@Reducer
struct AppFeature {
  struct State {
    var path = StackState<Path.State>()
    // ...
  }

  @Reducer
  enum Path {
    case addItem(AddFeature)
    case detailItem(DetailFeature)
    case editItem(EditFeature)
  }

  // ...
}
```

And for the view you can subclass `NavigationStackController` in order to drive navigation from the 
stack state:

```swift
class AppController: NavigationStackController {
  private var store: StoreOf<AppFeature>!

  convenience init(store: StoreOf<AppFeature>) {
    @UIBindable var store = store

    self.init(path: $store.scope(state: \.path, action: \.path)) {
      RootViewController(store: store)
    } destination: { store in 
      switch store.case {
      case .addItem(let store):
        AddViewController(store: store)
      case .detailItem(let store):
        DetailViewController(store: store)
      case .editItem(let store):
        EditViewController(store: store)
      }
    }

    self.model = model
  }
}
```


[swift-nav-gh]: http://github.com/pointfreeco/swift-navigation
