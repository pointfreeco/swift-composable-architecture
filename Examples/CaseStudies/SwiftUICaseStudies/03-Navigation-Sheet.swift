import ComposableArchitecture
import SwiftUI

struct SheetDemo: ReducerProtocol {
  struct State: Equatable {
    //@PresentationStateOf<AlertState<AlertAction>> var alert
    @PresentationStateOf<Destinations> var destination
  }

  enum Action: Equatable {
    case destination(PresentationActionOf<Destinations>)
    case swap
  }

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
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
        case .none:
          break
        }
        return .none
      }
    }
    // TODO: Can we hide away the behavior of detecting alert action and `nil`-ing out destination.
    // TODO: Can we also not send `dismiss` when writing `nil` to binding in view layer?
    .presentationDestination(\.$destination, action: /Action.destination) {
      Destinations()
    }
  }

  struct Destinations: ReducerProtocol {
    enum State: Equatable {
      // state.destination = .alert(.delete)
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
//      Scope(state: /State.alert, action: /Action.alert) {
//        /* library level reducer type */ AlertReducer()
//      }
      Scope(state: /State.animations, action: /Action.animations) {
        Animations()
      }
      Scope(state: /State.counter, action: /Action.counter) {
        Counter()
      }
    }
  }
}

struct SheetDemoView: View {
  let store: StoreOf<SheetDemo>

  var body: some View {
    WithViewStore(self.store.stateless) { viewStore in
      Form {
        Button("Animations") {
          viewStore.send(.destination(.present(.animations(Animations.State()))))
        }
        Button("Counter") {
          viewStore.send(.destination(.present(.counter(Counter.State()))))
        }
      }
      //      .sheet(
      //        store: self.store.scope(state: \.$sheet, action: SheetDemo.Action.sheet)
      //      ) { store in
      //        VStack {
      //          HStack {
      //            Button("Swap") {
      //              viewStore.send(.swap, animation: .default)
      //            }
      //            Button("Close") {
      //              viewStore.send(.sheet(.dismiss))
      //            }
      //          }
      //          .padding()
      //
      //          SwitchStore(store) {
      //            CaseLet(
      //              state: /SheetDemo.Destinations.State.animations,
      //              action: SheetDemo.Destinations.Action.animations,
      //              then: AnimationsView.init(store:)
      //            )
      //            CaseLet(
      //              state: /SheetDemo.Destinations.State.counter,
      //              action: SheetDemo.Destinations.Action.counter,
      //              then: CounterView.init(store:)
      //            )
      //          }
      //          .transition(.slide.combined(with: .opacity))
      //
      //          Spacer()
      //        }
      //      }
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
