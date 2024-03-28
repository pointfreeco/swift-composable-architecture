import ComposableArchitecture
import SwiftUI

private let readMe = """
  This demonstrates handling alerts and confirmation dialogs in the Composable Architecture using \
  bindable state objects.

  The library comes with `View.alert` overrides which allow optional state values to be bound, and \
  alert or confirmation dialogs will be displayed in the view when set to a non-`nil` value.

  The benefit of using these types is that you can get full test coverage on how a user interacts \
  with alerts and dialogs in your application
  """

@Reducer
struct AlertsAndConfirmationDialogs {
  @Reducer
  struct Increment {
    @ObservableState
    struct State: Equatable {
      
    }
    enum Action {
      case cancelButtonTapped
      case incrementButtonTapped
    }
  }
  
  @Reducer
  struct IncrementOrDecrement {
    enum Action {
      case cancelButtonTapped
      case decrementButtonTapped
      case incrementButtonTapped
    }
  }
  
  @Reducer
  struct Notice {
    @ObservableState
    struct State: Equatable {
      let title: LocalizedStringKey
    }
    
    enum Action {
      case okButtonTapped
    }
  }
  
  @Reducer(state: .equatable)
  enum Destination {
    case increment(Increment)
    case incrementOrDecrement(IncrementOrDecrement)
    case notice(Notice)
  }
  
  @ObservableState
  struct State: Equatable {
    @Presents var destination: Destination.State?
    var count = 0
  }

  enum Action {
    case alertButtonTapped
    case confirmationDialogButtonTapped
    case destination(PresentationAction<Destination.Action>)
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .alertButtonTapped:
        state.destination = .increment(Increment.State())
        return .none
        
      case .destination(.presented(.increment(.incrementButtonTapped))),
          .destination(.presented(.incrementOrDecrement(.incrementButtonTapped))):
        state.destination = .notice(Notice.State(title: "Incremented!"))
        state.count += 1
        return .none

      case .destination(.presented(.incrementOrDecrement(.decrementButtonTapped))):
        state.destination = .notice(Notice.State(title: "Decremented!"))
        state.count -= 1
        return .none
      
      case .destination(.presented(.notice(.okButtonTapped))):
        state.destination = nil
        return .none
        
      case .destination:
        return .none

      case .confirmationDialogButtonTapped:
        state.destination = .incrementOrDecrement(IncrementOrDecrement.State())
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination) {
      Destination.body
    }
  }
}

struct AlertsAndConfirmationDialogsView: View {
  @Bindable var store: StoreOf<AlertsAndConfirmationDialogs>
  
  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }
      
      Text("Count: \(store.count)")
      Button("Alert") { store.send(.alertButtonTapped) }
      Button("Confirmation Dialog") { store.send(.confirmationDialogButtonTapped) }
    }
    .navigationTitle("Alerts & Dialogs")
    // Notices
    .alert(item: $store.scope(state: \.destination?.notice, action: \.destination.notice)) { store in
      Text(store.title)
    } actions: { store in
      Button("OK") {
        store.send(.okButtonTapped)
      }
    }
    // Increment Alert
    .alert("Alert", item: $store.scope(state: \.destination?.increment, action: \.destination.increment)) { store in
      Button("Cancel", role: .cancel) {
        store.send(.cancelButtonTapped)
      }
      Button("Increment") {
        store.send(.incrementButtonTapped)
      }
    } message: { _ in
      Text("This is an alert.")
    }
    // Increment & Decrement Confirmation Dialog
    .confirmationDialog(
      "Confirmation dialog",
      item: $store.scope(state: \.destination?.incrementOrDecrement, action: \.destination.incrementOrDecrement),
      titleVisibility: .visible
    ) { store in
      Button("Cancel", role: .cancel) {
        store.send(.cancelButtonTapped)
      }
      Button("Increment") {
        store.send(.incrementButtonTapped)
      }
      Button("Decrement") {
        store.send(.decrementButtonTapped)
      }
    } message: { _ in
      Text("This is a confirmation dialog.")
    }
  }
}

#Preview {
  NavigationStack {
    AlertsAndConfirmationDialogsView(
      store: Store(initialState: AlertsAndConfirmationDialogs.State()) {
        AlertsAndConfirmationDialogs()
      }
    )
  }
}
