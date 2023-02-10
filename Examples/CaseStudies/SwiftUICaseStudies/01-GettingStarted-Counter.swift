import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates the basics of the Composable Architecture in an archetypal counter \
  application.

  The domain of the application is modeled using simple data types that correspond to the mutable \
  state of the application and any actions that can affect that state or the outside world.
  """

// MARK: - Feature domain

struct Counter: ReducerProtocol {
  struct State: Equatable {
    var count = 0
    @BindingState var text = "0"
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case decrementButtonTapped
    case incrementButtonTapped
  }

  var body: some ReducerProtocol<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none
      case .decrementButtonTapped:
        state.count -= 1
        return .none
      case .incrementButtonTapped:
        state.count += 1
        return .none
      }
    }
  }
}

// MARK: - Feature view

struct CounterView: View {
  let store: StoreOf<Counter>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        TextField("", text: viewStore.binding(\.$text))
        
        HStack {
          Button {
            viewStore.send(.decrementButtonTapped)
          } label: {
            Image(systemName: "minus")
          }
          
          Text("\(viewStore.count)")
            .monospacedDigit()
          
          Button {
            viewStore.send(.incrementButtonTapped)
          } label: {
            Image(systemName: "plus")
          }
        }
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
        store: Store(
          initialState: Counter.State(),
          reducer: Counter()
        )
      )
    }
  }
}
