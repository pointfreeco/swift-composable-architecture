import ComposableArchitecture
import SwiftUI
import SwiftUINavigation

struct SheetDemo: ReducerProtocol {
  struct State: Equatable {
    @PresentationState var destination: Destinations.State?
  }

  enum Action: Equatable {
    case alertButtonTapped
    case animationsButtonTapped
    case counterButtonTapped
    case destination(PresentationAction<Destinations.Action>)
    case swap
  }

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .alertButtonTapped:
        state.destination = .alert(.alert)
        return .none

      case .animationsButtonTapped:
        state.destination = .animations(Animations.State())
        return .none

      case .counterButtonTapped:
        state.destination = .counter(Counter.State())
        return .none

      case .destination(.presented(.counter(.decrementButtonTapped))):
        if case let .counter(counterState) = state.destination,
          counterState.count < 0
        {
          state.destination = nil
        }
        return .none

      case .destination:
        return .none

      case .swap:
        switch state.destination {
        case .some(.animations):
          state.destination = .counter(Counter.State())
        case .some(.counter):
          state.destination = .animations(Animations.State())
        case .some(.alert), .none:
          break
        }
        return .none
      }
    }
    .presentationDestination(\.$destination, action: /Action.destination) {
      Destinations()
    }
  }

  struct Destinations: ReducerProtocol {
    enum State: Equatable {
      case alert(AlertState<AlertAction>)
      case animations(Animations.State)
      case counter(Counter.State)
    }

    enum Action: Equatable {
      case alert(AlertAction)
      case animations(Animations.Action)
      case counter(Counter.Action)
    }

    enum AlertAction {
      case confirm
      case deny
    }

    var body: some ReducerProtocol<State, Action> {
      Scope(state: /State.animations, action: /Action.animations) {
        Animations()
      }
      Scope(state: /State.counter, action: /Action.counter) {
        Counter()
      }
    }
  }
}

extension AlertState where Action == SheetDemo.Destinations.AlertAction {
  static let alert: Self = AlertState {
    TextState("OK")
  } actions: {
    ButtonState(role: .destructive, action: .deny) { TextState("Deny") }
    ButtonState(role: .cancel) { TextState("OK") }
  }
}

func form(_ viewStore: ViewStore<Void, SheetDemo.Action>) -> some View {
  Form {
    Button("Alert") {
      viewStore.send(.alertButtonTapped)
    }
    Button("Animations") {
      viewStore.send(.animationsButtonTapped)
    }
    Button("Counter") {
      viewStore.send(.counterButtonTapped)
    }
  }
}

struct SheetDemoView: View {
  let store: StoreOf<SheetDemo>

  var body: some View {
    WithViewStore(self.store.stateless) { viewStore in
      form(viewStore)
      .alert(
        store: self.store.scope(state: \.$destination, action: SheetDemo.Action.destination),
        state: /SheetDemo.Destinations.State.alert,
        action: SheetDemo.Destinations.Action.alert
      )
      .sheet(
        store: self.store.scope(state: \.$destination, action: SheetDemo.Action.destination),
        state: /SheetDemo.Destinations.State.animations,
        action: SheetDemo.Destinations.Action.animations
      ) { store in
        VStack {
          HStack {
            Button("Swap") {
              viewStore.send(.swap, animation: .default)
            }
            Button("Close") {
              viewStore.send(.destination(.dismiss))
            }
          }
          .padding()

          AnimationsView(store: store)
          Spacer()
        }
      }
      .sheet(
        store: self.store.scope(state: \.$destination, action: SheetDemo.Action.destination),
        state: /SheetDemo.Destinations.State.counter,
        action: SheetDemo.Destinations.Action.counter
      ) { store in
        VStack {
          HStack {
            Button("Swap") {
              viewStore.send(.swap, animation: .default)
            }
            Button("Close") {
              viewStore.send(.destination(.dismiss))
            }
          }
          .padding()

          CounterView(store: store)
          Spacer()
        }
      }
    }
    .navigationTitle("Sheets")
  }
}

struct SheetDemo_Previews: PreviewProvider {
  static var previews: some View {
    SheetDemoView(
      store: Store(
        initialState: SheetDemo.State(),
        reducer: SheetDemo()
      )
    )
  }
}
