import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates the basics of the Composable Architecture in an archetypal counter \
  application.

  The domain of the application is modeled using simple data types that correspond to the mutable \
  state of the application and any actions that can affect that state or the outside world.
  """

struct CounterState: Equatable {
  var count = 0
}

enum CounterAction: Equatable {
  case decrementButtonTapped
  case incrementButtonTapped
}

struct CounterEnvironment {}

let counterReducer = Reducer<CounterState, CounterAction, CounterEnvironment> { state, action, _ in
  switch action {
  case .decrementButtonTapped:
    state.count -= 1
    return .none
  case .incrementButtonTapped:
    state.count += 1
    return .none
  }
}

struct CounterView: View {
  let store: Store<CounterState, CounterAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      HStack {
        Button("−") { viewStore.send(.decrementButtonTapped) }
        Text("\(viewStore.count)")
          .font(.body.monospacedDigit())
        Button("+") { viewStore.send(.incrementButtonTapped) }
      }
    }
  }
}

struct CounterDemoView: View {
  let store: Store<CounterState, CounterAction>

  var body: some View {
    Form {
      Section(header: Text(readMe)) {
        CounterView(store: self.store)
          .buttonStyle(.borderless)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .navigationBarTitle("Counter demo")
  }
}

struct CounterView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      CounterDemoView(
        store: Store(
          initialState: CounterState(),
          reducer: counterReducer,
          environment: CounterEnvironment()
        )
      )
    }
  }
}
