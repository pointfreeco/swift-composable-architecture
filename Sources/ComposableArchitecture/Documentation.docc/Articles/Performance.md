# Performance

Learn how to improve the performance of features built in the Composable Architecture.

As your features and application grow you may run into performance problems, such as reducers
becoming slow to execute, SwiftUI view bodies executing more often than expected, and more.
<!--memory usage growing.-->

* [View stores](#View-stores)
* [CPU-intensive calculations](#CPU-intensive-calculations)
* [High-frequency actions](#High-frequency-actions)
* [Compiler performance](#Compiler-performance)
<!--* [Memory usage](#Memory-usage)-->

### View stores

A common performance pitfall when using the library comes from constructing ``ViewStore``s. When 
constructed naively, using either view store's initializer ``ViewStore/init(_:)-1pfeq`` or the 
SwiftUI helper ``WithViewStore``, it will observe every change to state in the store:

```swift
WithViewStore(self.store, observe: { $0 }) { viewStore in 
  // This is executed for every action sent into the system 
  // that causes self.store.state to change. 
}
```

Most of the time this observes far too much state. A typical feature in the Composable Architecture
holds onto not only the state the view needs to present UI, but also state that the feature only
needs internally, as well as state of child features embedded in the feature. Changes to the
internal and child state should not cause the view's body to re-compute since that state is not
needed in the view.

For example, if the root of our application was a tab view, then we could model that in state as a
struct that holds each tab's state as a property:

```swift
struct AppState {
  var activity: ActivityState
  var search: SearchState
  var profile: ProfileState
}
```

If the view only needs to construct the views for each tab, then no view store is even needed
because we can pass scoped stores to each child feature view:

```swift
struct AppView: View {
  let store: Store<AppState, AppAction>

  var body: some View {
    // No need to observe state changes because the view does
    // not need access to the state.

    TabView {
      ActivityView(
        store: self.store
          .scope(state: \.activity, action: AppAction.activity)
      )
      SearchView(
        store: self.store
          .scope(state: \.search, action: AppAction.search)
      )
      ProfileView(
        store: self.store
          .scope(state: \.profile, action: AppAction.profile)
      )
    }
  }
}
```

This means `AppView` does not actually need to observe any state changes. This view will only be
created a single time, whereas if we observed the store then it would re-compute every time a single
thing changed in either the activity, search or profile child features.

If sometime in the future we do actually need some state from the store, we can start to observe
only the bare essentials of state necessary for the view to do its job. For example, suppose that 
we need access to the currently selected tab in state:

```swift
struct AppState {
  var activity: ActivityState
  var search: SearchState
  var profile: ProfileState
  var selectedTab: Tab
  enum Tab { case activity, search, profile }
}
```

Then we can observe this state so that we can construct a binding to `selectedTab` for the tab view:

```swift
struct AppView: View {
  let store: Store<AppState, AppAction>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      TabView(selection: viewStore.binding(send: AppAction.tabSelected) {
        ActivityView(
          store: self.store.scope(state: \.activity, action: AppAction.activity)
        )
        .tag(AppState.Tab.activity)
        SearchView(
          store: self.store.scope(state: \.search, action: AppAction.search)
        )
        .tag(AppState.Tab.search)
        ProfileView(
          store: self.store.scope(state: \.profile, action: AppAction.profile)
        )
        .tag(AppState.Tab.profile)
      }
    }
  }
}
```

However, this style of state observation is terribly inefficient since _every_ change to `AppState`
will cause the view to re-compute even though the only piece of state we actually care about is
the `selectedTab`. The reason we are observing too much state is because we use `observe: { $0 }`
in the construction of the ``WithViewStore``, which means the view store will observe all of state.

To chisel away at the observed state you can provide a closure for that argument that plucks out
the state the view needs. In this case the view only needs a single field:

```swift
WithViewStore(self.store, observe: \.selectedTab) { viewStore in
  TabView(selection: viewStore.binding(send: AppAction.tabSelected) {
    // ...
  }
}
```

In the future, the view may need access to more state. For example, suppose `ActivityState` holds
onto an `unreadCount` integer to represent how many new activities you have. There's no need to
observe _all_ of `ActivityState` to get access to this one field. You can observe just the one 
field.

Technically you can do this by mapping your state into a tuple, but because tuples are not 
`Equatable` you will need to provide an explicit `removeDuplicates` argument:

```swift
WithViewStore(
  self.store, 
  observe: { (selectedTab: $0.selectedTab, unreadActivityCount: $0.activity.unreadCount) },
  removeDuplicates: ==
) { viewStore in 
  TabView(selection: viewStore.binding(\.selectedTab, send: AppAction.tabSelected) {
    ActivityView(
      store: self.store.scope(state: \.activity, action: AppAction.activity)
    )
    .tag(AppState.Tab.activity)
    .badge("\(viewStore.unreadActivityCount)")

    // ...
  }
}
```

Alternatively, and recommended, you can introduce a lightweight, equatable `ViewState` struct
nested inside your view whose purpose is to transform the `Store`'s full state into the bare
essentials of what the view needs:

```swift
struct AppView: View {
  let store: Store<AppState, AppAction>
  
  struct ViewState: Equatable {
    let selectedTab: AppState.Tab
    let unreadActivityCount: Int
    init(state: AppState) {
      self.selectedTab = state.selectedTab
      self.unreadActivityCount = state.activity.unreadCount
    }
  }

  var body: some View {
    WithViewStore(self.store, observe: ViewState.init) { viewStore in 
      TabView {
        ActivityView(
          store: self.store
            .scope(state: \.activity, action: AppAction.activity
        )
        .badge("\(viewStore.unreadActivityCount)")

        // ...
      }
    }
  }
}
```

This gives you maximum flexibilty in the future for adding new fields to `ViewState` without making
your view convoluated.

This technique for reducing view re-computations is most effective towards the root of your app
hierarchy and least effective towards the leaf nodes of your app. Root features tend to hold lots
of state that its view does not need, such as child features, and leaf features tend to only hold
what's necessary. If you are going to employ this technique you will get the most benefit by
applying it to views closer to the root. At leaf features and views that need access to most
of the state, it is fine to continue using `observe: { $0 }` to observe all of the state in the 
store.

### CPU intensive calculations

Reducers are run on the main thread and so they are not appropriate for performing intense CPU
work. If you need to perform lots of CPU-bound work, then it is more appropriate to use an
``Effect``, which will operate in the cooperative thread pool, and then send actions back into the
system. You should also make sure to perform your CPU intensive work in a cooperative manner by
periodically suspending with `Task.yield()` so that you do not block a thread in the cooperative
pool for too long.

So, instead of performing intense work like this in your reducer:

```swift
case .buttonTapped:
  var result = // ...
  for value in someLargeCollection {
    // Some intense computation with value
  }
  state.result = result
```

...you should return an effect to perform that work, sprinkling in some yields every once in awhile,
and then delivering the result in an action:

```swift
case .buttonTapped:
  return .task {
    var result = // ...
    for (index, value) in someLargeCollection.enumerated() {
      // Some intense computation with value

      // Yield every once in awhile to cooperate in the thread pool.
      if index.isMultiple(of: 1_000) {
        await Task.yield()
      }
    }
    return .response(result)
  }

case let .response(result):
  state.result = result
```

This will keep CPU intense work from being performed in the reducer, and hence not on the main 
thread.

### High-frequency actions

Sending actions in a Composable Architecture application should not be thought as simple method
calls that one does with classes, such as `ObservableObject` conformances. When an action is sent
into the system there are multiple layers of features that can intercept and interpret it, and 
the resulting state changes can reverberate throughout the entire application.

Because of this, sending actions do come with a cost. You should aim to only send "significant" 
actions into the system, that is, actions that cause the execution of important logic and effects
for your application. High-frequency actions, such as sending dozens of actions per second, 
should be avoided unless your application truly needs that volume of actions in order to implement
its logic.

However, there are often times that actions are sent at a high frequency but the reducer doesn't
actually need that volume of information. For example, say you were constructing an effect that 
wanted to report its progress back to the system for each step of its work. You could choose to send
the progress for literally every step:

```swift
case .startButtonTapped:
  return .run { send in
    var count = 0
    let max = await environment.eventCount()

    for await event in environment.eventSource() {
      defer { count += 1 }
      send(.progress(Double(count) / Double(max)))
    }
  }
}
```

However, what if the effect required 10,000 steps to finish? Or 100,000? Or more? It would be 
immensely wasteful to send 100,000 actions into the system to report a progress value that is only
going to vary from 0.0 to 1.0.

Instead, you can choose to report the progress every once in awhile. You can even do the math
to make it so that you report the progress at most 100 times:

```swift
case .startButtonTapped:
  return .run { send in
    var count = 0
    let max = await environment.eventCount()
    let interval = max / 100

    for await event in environment.eventSource() {
      defer { count += 1 }
      if count.isMultiple(of: interval) {
        send(.progress(Double(count) / Double(max)))
      }
    }
  }
}
```

This greatly reduces the bandwidth of actions being sent into the system so that you are not 
incurring unnecessary costs for sending actions.

### Compiler performance

In very large SwiftUI applications you may experience degraded compiler performance causing long
compile times, and possibly even compiler failures due to "complex expressions." The
``WithViewStore``  helpers that comes with the library can exacerbate that problem for very complex
views. If you are running into issues using ``WithViewStore`` you can make a small change to your
view to use an `@ObservedObject` directly.

For example, if your view looks like this:

```swift
struct FeatureView: View {
  let store: Store<FeatureState, FeatureAction>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      // A large, complex view inside here...
    }
  }
}
```

...and you start running into compiler troubles, then you can refactor to the following:

```swift
struct FeatureView: View {
  let store: Store<FeatureState, FeatureAction>
  @ObservedObject var viewStore: ViewStore<FeatureState, FeatureAction>

  init(store: Store<FeatureState, FeatureAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store))
  }

  var body: some View {
    // A large, complex view inside here...
  }
}
```

That should greatly improve the compiler's ability to type-check your view.
