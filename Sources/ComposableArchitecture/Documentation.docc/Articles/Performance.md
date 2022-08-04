# Performance

Learn how to improve the performance of features built in the Composable Architecture.

As your features and application grow you may run into performance problems, such as reducers
becoming slow to execute, SwiftUI view bodies executing more often than expected, and more.
<!--memory usage growing.-->

* [View stores](#View-stores)
* [CPU-intensive calculations](#CPU-intensive-calculations)
* [High-frequency actions](#High-frequency-actions)
<!--* [Memory usage](#Memory-usage)-->

### View stores

A common performance pitfall when using the library comes from constructing ``ViewStore``s. When 
constructed naively, using either view store's initializer ``ViewStore/init(_:)-1pfeq`` or the 
SwiftUI helper ``WithViewStore``, it will observe every change to state in the store:

```swift
WithViewStore(self.store) { viewStore in 
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

If sometime in the future we do actually need some state from the store, we can create a localized
"view state" struct that holds only the bare essentials of state that the view needs to do its
job. For example, suppose the activity state holds an integer that represents the number of 
unread activities. Then we could observe changes to only that piece of state like so:

```swift
struct AppView: View {
  let store: Store<AppState, AppAction>
  
  struct ViewState {
    let unreadActivityCount: Int
    init(state: AppState) {
      self.unreadActivityCount = state.activity.unreadCount
    }
  }

  var body: some View {
    WithViewStore(
      self.store.scope(state: ViewState.init)
    ) { viewStore in 
      TabView {
        ActivityView(
          store: self.store
            .scope(state: \.activity, action: AppAction.activity
        )
        .badge("\(viewStore.unreadActivityCount)")

        …
      }
    }
  }
}
```

Now the `AppView` will re-compute its body only when `activity.unreadCount` changes. In particular,
no changes to the search or profile features will cause the view to re-compute, and that greatly
reduces how often the view must re-compute.

This technique for reducing view re-computations is most effective towards the root of your app
hierarchy and least effective towards the leaf nodes of your app. Root features tend to hold lots
of state that its view does not need, such as child features, and leaf features tend to only hold
what's necessary. If you are going to employ this technique you will get the most benefit by
applying it to views closer to the root.

### CPU intensive calculations

Reducers are run on the main thread and so they are not appropriate for performing intense CPU
work. If you need to perform lots of CPU-bound work, then it is more appropriate to use an
``Effect``, which will operate in the cooperative thread pool, and then send it's output back into
the system via an action. You should also make sure to perform your CPU intensive work in a
cooperative manner by periodically suspending with `Task.yield()` so that you do not block a thread
in the cooperative pool for too long.

So, instead of performing intense work like this in your reducer:

```swift
case .buttonTapped:
  var result = …
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
    var result = …
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

<!--### Memory usage-->
