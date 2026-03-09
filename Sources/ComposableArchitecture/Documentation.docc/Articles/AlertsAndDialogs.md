# Alerts and Dialogs

Learn how to present alerts and confirmation dialogs in a testable, state-driven way.

## Overview

The Composable Architecture provides tools for presenting alerts and confirmation dialogs in a
state-driven manner. This allows you to model your alerts as data, making them easy to test and
easy to reason about.

## Modeling alert state

To present an alert, add an `@Presents` property to your state that holds an `AlertState`:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    // ...
  }
  
  enum Action {
    case alert(PresentationAction<Alert>)
    case deleteButtonTapped
    
    @CasePathable
    enum Alert {
      case confirmButtonTapped
    }
  }
  // ...
}
```

The `AlertState` type describes the content of the alert, including its title, message, and
buttons. It is generic over the action type that the alert can send.

## Creating alert state

You can create an `AlertState` value using a result builder syntax that closely mirrors SwiftUI's
`alert` modifier:

```swift
extension AlertState where Action == Feature.Action.Alert {
  static let deleteConfirmation = Self {
    TextState("Delete Item")
  } actions: {
    ButtonState(role: .destructive, action: .confirmButtonTapped) {
      TextState("Delete")
    }
    ButtonState(role: .cancel) {
      TextState("Cancel")
    }
  } message: {
    TextState("Are you sure you want to delete this item?")
  }
}
```

## Presenting and dismissing alerts

To present an alert, assign the `AlertState` value to your state property:

```swift
case .deleteButtonTapped:
  state.alert = .deleteConfirmation
  return .none
```

The alert will automatically dismiss when the user taps a button. You can also dismiss the alert
programmatically by setting the state to `nil`:

```swift
case .alert(.dismiss):
  state.alert = nil
  return .none
```

## Integrating with SwiftUI

To display the alert in your view, use the `alert` modifier with the `store` parameter:

```swift
struct FeatureView: View {
  let store: StoreOf<Feature>
  
  var body: some View {
    Button("Delete") {
      store.send(.deleteButtonTapped)
    }
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}
```

## Handling alert actions

When the user taps a button in the alert, the associated action is sent to your reducer. Handle
these actions just like any other action:

```swift
case .alert(.presented(.confirmButtonTapped)):
  // Handle the delete confirmation
  return .none
```

## Confirmation dialogs

Confirmation dialogs work similarly to alerts. Use `ConfirmationDialogState` instead of
`AlertState`:

```swift
@ObservableState
struct State: Equatable {
  @Presents var confirmationDialog: ConfirmationDialogState<Action.ConfirmationDialog>?
  // ...
}

enum Action {
  case confirmationDialog(PresentationAction<ConfirmationDialog>)
  // ...
  
  @CasePathable
  enum ConfirmationDialog {
    case option1Selected
    case option2Selected
  }
}
```

And in your view:

```swift
.confirmationDialog($store.scope(state: \.confirmationDialog, action: \.confirmationDialog))
```

## Testing alerts

Because alerts are modeled as data, they are easy to test. You can assert that the alert state
is set correctly and simulate button taps:

```swift
let store = TestStore(initialState: Feature.State()) {
  Feature()
}

await store.send(.deleteButtonTapped) {
  $0.alert = .deleteConfirmation
}

await store.send(.alert(.presented(.confirmButtonTapped))) {
  // Assert expected state changes after confirmation
  $0.alert = nil
}
```

## Topics

### State types

- ``AlertState``
- ``ConfirmationDialogState``

### SwiftUI integration

- ``SwiftUI/View/alert(_:)``
- ``SwiftUI/View/confirmationDialog(_:)``

### Reducer tools

- ``Presents()``
- ``PresentationAction``
- ``Reducer/ifLet(_:action:destination:fileID:filePath:line:column:)-4ub6q``
