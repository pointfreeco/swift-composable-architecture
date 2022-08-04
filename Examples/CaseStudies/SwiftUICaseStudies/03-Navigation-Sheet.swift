import ComposableArchitecture
import SwiftUI

struct SheetDemo: ReducerProtocol {
  struct State: Equatable {
    @PresentationState var sheet: DestinationState?
  }

  enum Action: Equatable {
    case sheet(PresentationAction<DestinationState, DestinationAction>)
    case swap
  }

  enum DestinationState: Equatable {
    case animations(Animations.State)
    case counter(Counter.State)
  }

  enum DestinationAction: Equatable {
    case animations(Animations.Action)
    case counter(Counter.Action)
  }

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .sheet:
        return .none
      case .swap:
        switch state.sheet {
        case .some(.animations):
          state.$sheet.present(.counter(Counter.State()))
        case .some(.counter):
          state.$sheet.present(.animations(Animations.State()))
        case .none:
          break
        }
        return .none
      }
    }
    .presentationDestination(state: \.$sheet, action: /Action.sheet) {
      ScopeCase(
        state: /DestinationState.animations,
        action: /DestinationAction.animations
      ) {
        Animations()
      }
      ScopeCase(
        state: /DestinationState.counter,
        action: /DestinationAction.counter
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
      VStack {
        Button("Animations") {
          viewStore.send(.sheet(.present(.animations(Animations.State()))))
        }
        Button("Counter") {
          viewStore.send(.sheet(.present(.counter(Counter.State()))))
        }
      }
      .sheet(
        store: self.store.scope(state: \.$sheet, action: SheetDemo.Action.sheet)
      ) { destinationStore in
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

          SwitchStore(destinationStore) {
            CaseLet(
              state: /SheetDemo.DestinationState.animations,
              action: SheetDemo.DestinationAction.animations,
              then: AnimationsView.init(store:)
            )
            CaseLet(
              state: /SheetDemo.DestinationState.counter,
              action: SheetDemo.DestinationAction.counter,
              then: CounterView.init(store:)
            )
          }
          .transition(.slide.combined(with: .opacity))

          Spacer()
        }
      }
    }
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
