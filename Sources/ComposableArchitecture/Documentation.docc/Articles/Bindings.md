# Working with SwiftUI bindings

Learn how to connect features written in the Composable Architecture to SwiftUI bindings.

## Overview

Many APIs in SwiftUI use bindings to set up two-way communication between your application's state
and a view. The Composable Architecture provides several tools for creating bindings that establish
such communication with your application's store.

### Ad hoc bindings

The simplest tool for creating bindings that communicate with your store is 
``ViewStore/binding(get:send:)-65xes``, which is handed two closures: one that describes how to
transform state into the binding's value, and one that describes how to transform the binding's
value into an action that can be fed back into the store.

For example, a reducer may have a domain that tracks if user has enabled haptic feedback. First, it
can define a boolean property on state:

```swift
struct Settings: ReducerProtocol {
  struct State: Equatable {
    var isHapticFeedbackEnabled = true
    // ...
  }

  // ...
}
```

Then, in order to allow the outside world to mutate this state, for example from a toggle, it must
define a corresponding action that can be sent updates:

```swift
struct Settings: ReducerProtocol {
  struct State: Equatable { /* ... */ }

  enum Action { 
    case isHapticFeedbackEnabledChanged(Bool)
    // ...
  }

  // ...
}
```

When the reducer handles this action, it can update state accordingly:

```swift
struct Settings: ReducerProtocol {
  struct State: Equatable { /* ... */ }
  enum Action { /* ... */ }
  
  func reduce(
    into state: inout State, action: Action
  ) -> EffectTask<Action> {
    switch action {
    case let .isHapticFeedbackEnabledChanged(isEnabled):
      state.isHapticFeedbackEnabled = isEnabled
      return .none

    // ...
    }
  }
}
```

And finally, in the view, we can derive a binding from the domain that allows a toggle to
communicate with our Composable Architecture feature:

```swift
struct SettingsView: View {
  let store: StoreOf<Settings>
  
  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Toggle(
          "Haptic feedback",
          isOn: viewStore.binding(
            get: \.isHapticFeedbackEnabled,
            send: { .isHapticFeedbackEnabledChanged($0) }
          )
        )

        // ...
      }
    }
  }
}
```

### Bindable state, actions, and reducers

Deriving ad hoc bindings requires many manual steps that can feel tedious, especially for screens
with many controls driven by many bindings. Because of this, the Composable Architecture comes with
a collection of tools that can be applied to a reducer's domain and logic to make this easier.

For example, a settings screen may model its state with the following struct:

```swift
struct Settings: ReducerProtocol {
  struct State: Equatable {
    var digest = Digest.daily
    var displayName = ""
    var enableNotifications = false
    var isLoading = false
    var protectMyPosts = false
    var sendEmailNotifications = false
    var sendMobileNotifications = false
  }

  // ...
}
```

The majority of these fields should be editable by the view, and in the Composable Architecture this
means that each field requires a corresponding action that can be sent to the store. Typically this
comes in the form of an enum with a case per field:

```swift
struct Settings: ReducerProtocol {
  struct State: Equatable { /* ... */ }

  enum Action {
    case digestChanged(Digest)
    case displayNameChanged(String)
    case enableNotificationsChanged(Bool)
    case protectMyPostsChanged(Bool)
    case sendEmailNotificationsChanged(Bool)
    case sendMobileNotificationsChanged(Bool)
  }

  // ...
}
```

And we're not even done yet. In the reducer we must now handle each action, which simply replaces
the state at each field with a new value:

```swift
struct Settings: ReducerProtocol {
  struct State: Equatable { /* ... */ }
  enum Action { /* ... */ }

  func reduce(
    into state: inout State, action: Action
  ) -> EffectTask<Action> {
    switch action {
    case let digestChanged(digest):
      state.digest = digest
      return .none

    case let displayNameChanged(displayName):
      state.displayName = displayName
      return .none

    case let enableNotificationsChanged(isOn):
      state.enableNotifications = isOn
      return .none

    case let protectMyPostsChanged(isOn):
      state.protectMyPosts = isOn
      return .none

    case let sendEmailNotificationsChanged(isOn):
      state.sendEmailNotifications = isOn
      return .none

    case let sendMobileNotificationsChanged(isOn):
      state.sendMobileNotifications = isOn
      return .none
    }
  }
}
```

This is a _lot_ of boilerplate for something that should be simple. Luckily, we can dramatically
eliminate this boilerplate using ``BindableState``, ``BindableAction``, and ``BindingReducer``.

First, we can annotate each bindable value of state with the ``BindableState`` property wrapper:

```swift
struct Settings: ReducerProtocol {
  struct State: Equatable {
    @BindableState var digest = Digest.daily
    @BindableState var displayName = ""
    @BindableState var enableNotifications = false
    var isLoading = false
    @BindableState var protectMyPosts = false
    @BindableState var sendEmailNotifications = false
    @BindableState var sendMobileNotifications = false
  }

  // ...
}
```

Each annotated field is directly bindable to SwiftUI controls, like pickers, toggles, and text
fields. Notably, the `isLoading` property is _not_ annotated as being bindable, which prevents the
view from mutating this value directly.

Next, we can conform the action type to ``BindableAction`` by collapsing all of the individual,
field-mutating actions into a single case that holds a ``BindingAction`` generic over the reducer's
state:

```swift
struct Settings: ReducerProtocol {
  struct State: Equatable { /* ... */ }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
  }

  // ...
}
```

And then, we can simplify the settings reducer by allowing the ``BindingReducer`` to handle these
field mutations for us:

```swift
struct Settings: ReducerProtocol {
  struct State: Equatable { /* ... */ }
  enum Action: BindableAction { /* ... */ }

  var body: some ReducerProtocol<State, Action> {
    BindingReducer()
  }
}
```

Binding actions are constructed and sent to the store by calling
``ViewStore/binding(_:file:fileID:line:)`` with a key path to the bindable state:

```swift
TextField("Display name", text: viewStore.binding(\.$displayName))
```

Should you need to layer additional functionality over these bindings, your reducer can pattern
match the action for a given key path:

```swift
var body: some ReducerProtocol<State, Action> {
  BindingReducer()

  Reduce { state, action in 
    case .binding(\.$displayName):
      // Validate display name
  
    case .binding(\.$enableNotifications):
      // Return an authorization request effect
  
    // ...
  }
}
```

Binding actions can also be tested in much the same way regular actions are tested. Rather than send
a specific action describing how a binding changed, such as `.displayNameChanged("Blob")`, you will
send a ``BindingAction`` action that describes which key path is being set to what value, such as
`.set(\.$displayName, "Blob")`:

```swift
let store = TestStore(
  initialState: Settings.State(),
  reducer: Settings()
)

store.send(.set(\.$displayName, "Blob")) {
  $0.displayName = "Blob"
}
store.send(.set(\.$protectMyPosts, true)) {
  $0.protectMyPosts = true
)
```
