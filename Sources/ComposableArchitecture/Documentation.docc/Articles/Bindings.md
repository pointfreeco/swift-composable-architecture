# Working with SwiftUI bindings

Learn how to connect features written in the Composable Architecture to SwiftUI bindings.

## Overview

Many APIs in SwiftUI use bindings to set up two-way communication between your application's state
and a view. The Composable Architecture provides several tools for creating bindings that establish
such communication with your application's store.

### Ad hoc bindings

The simplest tool for creating bindings that communicate with your store is to create a dedicated
action that can change a piece of state in your feature. For example, a reducer may have a domain
that tracks if the user has enabled haptic feedback. First, it can define a boolean property on
state:

```swift
@Reducer
struct Settings {
  struct State: Equatable {
    var isHapticsEnabled = true
    // ...
  }

  // ...
}
```

Then, in order to allow the outside world to mutate this state, for example from a toggle, it must
define a corresponding action that can be sent updates:

```swift
@Reducer
struct Settings {
  struct State: Equatable { /* ... */ }

  enum Action { 
    case isHapticsEnabledChanged(Bool)
    // ...
  }

  // ...
}
```

When the reducer handles this action, it can update state accordingly:

```swift
@Reducer
struct Settings {
  struct State: Equatable { /* ... */ }
  enum Action { /* ... */ }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .isHapticsEnabledChanged(isEnabled):
        state.isHapticsEnabled = isEnabled
        return .none
      // ...
      }
    }
  }
}
```

And finally, in the view, we can derive a binding from the domain that allows a toggle to 
communicate with our Composable Architecture feature. First you must hold onto the store in a 
bindable way, which can be done using the `@Bindable` property wrapper from SwiftUI:

```swift
struct SettingsView: View {
  @Bindable var store: StoreOf<Settings>
  // ...
}
```

> Important: If you are targeting older Apple platforms (iOS 16, macOS 13, tvOS 16, watchOS 9, or
> less), then you must use our backport of the `@Bindable` property wrapper:
>
> ```diff
> -@Bindable var store: StoreOf<Settings>
> +@Perception.Bindable var store: StoreOf<Settings>
> ```

Once that is done you can derive a binding to a piece of state that sends an action when the 
binding is mutated:

```swift
var body: some View {
  Form {
    Toggle(
      "Haptic feedback",
      isOn: $store.isHapticsEnabled.sending(\.isHapticsEnabledChanged)
    )

    // ...
  }
}
```

### Binding actions and reducers

Deriving ad hoc bindings requires many manual steps that can feel tedious, especially for screens
with many controls driven by many bindings. Because of this, the Composable Architecture comes with
tools that can be applied to a reducer's domain and logic to make this easier.

For example, a settings screen may model its state with the following struct:

```swift
@Reducer
struct Settings {
  @ObservableState
  struct State {
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
@Reducer
struct Settings {
  @ObservableState
  struct State { /* ... */ }

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
@Reducer
struct Settings {
  @ObservableState
  struct State { /* ... */ }
  enum Action { /* ... */ }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
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
}
```

This is a _lot_ of boilerplate for something that should be simple. Luckily, we can dramatically
eliminate this boilerplate using ``BindableAction`` and ``BindingReducer``.

First, we can conform the action type to ``BindableAction`` by collapsing all of the individual,
field-mutating actions into a single case that holds a ``BindingAction`` that is generic over the
reducer's state:

```swift
@Reducer
struct Settings {
  @ObservableState
  struct State { /* ... */ }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
  }

  // ...
}
```

And then, we can simplify the settings reducer by adding a ``BindingReducer`` that handles these
field mutations for us:

```swift
@Reducer
struct Settings {
  @ObservableState
  struct State { /* ... */ }
  enum Action: BindableAction { /* ... */ }

  var body: some Reducer<State, Action> {
    BindingReducer()
  }
}
```

Then in the view you must hold onto the store in a bindable manner, which can be done using the
`@Bindable` property wrapper (or the backported tool `@Perception.Bindable` if targeting older
Apple platforms):

```swift
struct SettingsView: View {
  @Bindable var store: StoreOf<Settings>
  // ...
}
```

Then bindings can be derived from the store using familiar `$` syntax:

```swift
TextField("Display name", text: $store.displayName)
Toggle("Notifications", text: $store.enableNotifications)
// ...
```

Should you need to layer additional functionality over these bindings, your can pattern match the
action for a given key path in the reducer:

```swift
var body: some Reducer<State, Action> {
  BindingReducer()

  Reduce { state, action in
    switch action
    case .binding(\.displayName):
      // Validate display name
  
    case .binding(\.enableNotifications):
      // Return an effect to request authorization from UNUserNotificationCenter
  
    // ...
    }
  }
}
```

Or you can apply ``Reducer/onChange(of:_:)`` to the ``BindingReducer`` to react to changes to
particular fields:

```swift
var body: some Reducer<State, Action> {
  BindingReducer()
    .onChange(of: \.displayName) { oldValue, newValue in
      // Validate display name
    }
    .onChange(of: \.enableNotifications) { oldValue, newValue in
      // Return an authorization request effect
    }

  // ...
}
```

Binding actions can also be tested in much the same way regular actions are tested. Rather than send
a specific action describing how a binding changed, such as `.displayNameChanged("Blob")`, you will
send a ``BindingAction`` action that describes which key path is being set to what value, such as
`\.displayName, "Blob"`:

```swift
let store = TestStore(initialState: Settings.State()) {
  Settings()
}

store.send(\.binding.displayName, "Blob") {
  $0.displayName = "Blob"
}
store.send(\.binding.protectMyPosts, true) {
  $0.protectMyPosts = true
)
```
