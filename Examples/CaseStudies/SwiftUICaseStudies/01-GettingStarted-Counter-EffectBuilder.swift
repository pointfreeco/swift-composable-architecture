import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates the basics of the Composable Architecture in an archetypal counter \
  application.

  The domain of the application is modeled using simple data types that correspond to the mutable \
  state of the application and any actions that can affect that state or the outside world.
  """

struct CounterBuilderState: Equatable {
  var count = 0
}

enum CounterBuilderAction: Equatable {
  case decrementButtonTapped
  case incrementButtonTapped
  
  case doubleIncrementButtonTapped
  case doubleDecrementButtonTapped
}

struct CounterBuilderEnvironment {}

let counterBuilderReducer = Reducer<CounterBuilderState, CounterBuilderAction, CounterBuilderEnvironment> { state, action, _ in
  switch action {
  case .decrementButtonTapped:
    state.count -= 1
  case .incrementButtonTapped:
    state.count += 1
  case .doubleDecrementButtonTapped:
    if state.count >= 2 {
      CounterBuilderAction.decrementButtonTapped
      CounterBuilderAction.decrementButtonTapped
    }
  case .doubleIncrementButtonTapped:
    CounterBuilderAction.incrementButtonTapped
    CounterBuilderAction.incrementButtonTapped
  }
}

struct CounterBuilderView: View {
  let store: Store<CounterBuilderState, CounterBuilderAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      HStack {
        Button("−−") { viewStore.send(.doubleDecrementButtonTapped) }
          .disabled(viewStore.state.count < 2)
        Button("−") { viewStore.send(.decrementButtonTapped) }
        Text("\(viewStore.count)")
          .font(.body.monospacedDigit())
        Button("+") { viewStore.send(.incrementButtonTapped) }
        Button("++") { viewStore.send(.doubleIncrementButtonTapped) }
      }
    }
  }
}

struct CounterBuilderDemoView: View {
  let store: Store<CounterBuilderState, CounterBuilderAction>

  var body: some View {
    Form {
      Section(header: Text(readMe)) {
        CounterBuilderView(store: self.store)
          .buttonStyle(.borderless)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .navigationBarTitle("Counter demo")
  }
}

struct CounterBuilderView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      CounterBuilderDemoView(
        store: Store(
          initialState: CounterBuilderState(),
          reducer: counterBuilderReducer,
          environment: CounterBuilderEnvironment()
        )
      )
    }
  }
}
