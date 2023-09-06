import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates the basics of the Composable Architecture in an archetypal counter \
  application.

  The domain of the application is modeled using simple data types that correspond to the mutable \
  state of the application and any actions that can affect that state or the outside world.
  """

// MARK: - Feature domain

/*

 set {
   if newValue is any ObservableState {
     if identityChanged(newValue, currentValue) {
       withMutation

 */

struct Counter: Reducer {
  @ObservableState
  struct State: Equatable {
    var count = 0
  }

  enum Action: Equatable {
    case decrementButtonTapped
    case incrementButtonTapped
  }

  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .decrementButtonTapped:
      state.count -= 1
      return .none
    case .incrementButtonTapped:
      state.count += 1
      return .none
    }
  }
}

// MARK: - Feature view

struct CounterView: View {
  @State var store: StoreOf<Counter>

  var body: some View {
    let _ = Self._printChanges()
    HStack {
      Button {
        store.send(.decrementButtonTapped)
      } label: {
        Image(systemName: "minus")
      }

      Text("\(store.count)")
        .monospacedDigit()

      Button {
        store.send(.incrementButtonTapped)
      } label: {
        Image(systemName: "plus")
      }
    }
  }
}

struct CounterDemoView: View {
  let store: StoreOf<Counter>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      Section {
        CounterView(store: self.store)
          .frame(maxWidth: .infinity)
      }
    }
    .buttonStyle(.borderless)
    .navigationTitle("Counter demo")
  }
}

// MARK: - SwiftUI previews

struct CounterView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      CounterDemoView(
        store: Store(initialState: Counter.State()) {
          Counter()
        }
      )
    }
  }
}
