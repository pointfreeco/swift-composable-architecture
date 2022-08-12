import ComposableArchitecture
import SwiftUI

struct SheetDemo: ReducerProtocol {
  struct State: Equatable {
    @PresentationStateOf<Destinations> var sheet
  }

  enum Action: Equatable {
    case sheet(PresentationActionOf<Destinations>)
    case swap
  }

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .sheet:
        return .none
      case .swap:
        switch state.sheet {
        case .some(.animations):
          state.sheet = .counter(Counter.State())
        case .some(.counter):
          state.sheet = .animations(Animations.State())
        case .none:
          break
        }
        return .none
      }
    }
    .presentationDestination(\.$sheet, action: /Action.sheet) {
      Destinations()
    }
  }

  struct Destinations: ReducerProtocol {
    enum State: Equatable {
      case animations(Animations.State)
      case counter(Counter.State)
    }

    enum Action: Equatable {
      case animations(Animations.Action)
      case counter(Counter.Action)
    }

    var body: some ReducerProtocol<State, Action> {
      Scope(
        state: /State.animations,
        action: /Action.animations
      ) {
        Animations()
      }
      Scope(
        state: /State.counter,
        action: /Action.counter
      ) {
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
          viewStore.send(.sheet(.present(.animations(Animations.State()))))
        }
        Button("Counter") {
          viewStore.send(.sheet(.present(.counter(Counter.State()))))
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
        store: self.store.scope(state: \.$sheet, action: SheetDemo.Action.sheet),
        state: /SheetDemo.Destinations.State.animations,
        action: SheetDemo.Destinations.Action.animations
      ) { store in
        VStack {
          HStack {
            Button("Swap") {
              viewStore.send(.swap, animation: .default)
            }
            Button("Close") {
              viewStore.send(.sheet(.dismiss))
            }
          }
          .padding()

          AnimationsView(store: store)
          Spacer()
        }
      }
      .sheet(
        store: self.store.scope(state: \.$sheet, action: SheetDemo.Action.sheet),
        state: /SheetDemo.Destinations.State.counter,
        action: SheetDemo.Destinations.Action.counter
      ) { store in
        VStack {
          HStack {
            Button("Swap") {
              viewStore.send(.swap, animation: .default)
            }
            Button("Close") {
              viewStore.send(.sheet(.dismiss))
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
