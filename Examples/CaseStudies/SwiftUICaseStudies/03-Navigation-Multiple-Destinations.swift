import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates handling multiple destinations

  Tapping "Show sheet" or "Show popover" shows a sheet or a popover with a composable feature.
  """

struct MultipleDestinations: ReducerProtocol {
    
    public struct Destination: ReducerProtocol {
        public enum State: Equatable {
            case sheet(PresentAndLoad.State)
            case popover(Counter.State)
        }

        public enum Action {
            case sheet(PresentAndLoad.Action)
            case popover(Counter.Action)
        }

        public var body: some ReducerProtocol<State, Action> {
            Scope(state: /State.sheet, action: /Action.sheet) {
                PresentAndLoad()
            }
            Scope(state: /State.popover, action: /Action.popover) {
                Counter()
            }
        }
    }
    
    struct State: Equatable {
        @PresentationState var destination: Destination.State?
    }
    
    enum Action {
        case destination(PresentationAction<Destination.Action>)
        case showSheet
        case showPopover
    }
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
                case .showSheet:
                    state.destination = .sheet(.init())
                    return .none
                case .showPopover:
                    state.destination = .popover(.init())
                    return .none
                case .destination(.presented):
                    print("Presenting a destination")
                    return .none
                case .destination(.dismiss):
                    print("Dismissing a destination")
                    return .none
            }
        }
        .ifLet(\.$destination, action: /Action.destination) {
            Destination()
        }
    }
}

struct MultipleDestinationsView: View {
    
    let store: StoreOf<MultipleDestinations>
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            Form {
                Section {
                    AboutView(readMe: readMe)
                }
                Button("Show sheet") {
                    viewStore.send(.showSheet)
                }
                Button("Show popover") {
                    viewStore.send(.showPopover)
                }
            }
            .sheet(
              store: store.scope(state: \.$destination, action: { .destination($0) }),
              state: /MultipleDestinations.Destination.State.sheet,
              action: MultipleDestinations.Destination.Action.sheet
            ) {
                PresentAndLoadView(store: $0)
            }
            .popover(
              store: store.scope(state: \.$destination, action: { .destination($0) }),
              state: /MultipleDestinations.Destination.State.popover,
              action: MultipleDestinations.Destination.Action.popover
            ) {
                CounterView(store: $0)
            }
        }
    }
}
