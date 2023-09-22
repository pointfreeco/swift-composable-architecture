import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates driving 3 kinds of navigation (drill down, sheet, popover) from a single
  piece of enum state.
  """

struct MultipleDestinations: Reducer {
  public struct Destination: Reducer {
    @ObservableState
    @CasePathable
    public enum State: Equatable {
      case drillDown(Counter.State)
      case popover(Counter.State)
      case sheet(Counter.State)
    }

    @CasePathable
    public enum Action {
      case drillDown(Counter.Action)
      case popover(Counter.Action)
      case sheet(Counter.Action)
    }

    public var body: some Reducer<State, Action> {
      Scope(state: #casePath(\.drillDown), action: #casePath(\.drillDown)) {
        Counter()
      }
      Scope(state: #casePath(\.sheet), action: #casePath(\.sheet)) {
        Counter()
      }
      Scope(state: #casePath(\.popover), action: #casePath(\.popover)) {
        Counter()
      }
    }
  }

  @ObservableState
  struct State: Equatable {
    @ObservationStateIgnored
    @PresentationState var destination: Destination.State?
  }

  @CasePathable
  enum Action {
    case destination(PresentationAction<Destination.Action>)
    case showDrillDown
    case showPopover
    case showSheet
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .showDrillDown:
        state.destination = .drillDown(Counter.State())
        return .none
      case .showPopover:
        state.destination = .popover(Counter.State())
        return .none
      case .showSheet:
        state.destination = .sheet(Counter.State())
        return .none
      case .destination:
        return .none
      }
    }
    .ifLet(\.$destination, action: #casePath(\.destination)) {
      Destination()
    }
  }
}

struct MultipleDestinationsView: View {
  @State var store: StoreOf<MultipleDestinations>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }
        Button("Show drill-down") {
          viewStore.send(.showDrillDown)
        }
        Button("Show popover") {
          viewStore.send(.showPopover)
        }
        Button("Show sheet") {
          viewStore.send(.showSheet)
        }
      }
      .navigationDestination(item: $store.scope(#feature(\.destination?.drillDown))) {
        CounterView(store: $0)
      }
      .popover(item: $store.scope(#feature(\.destination?.popover))) {
        CounterView(store: $0)
      }
      .popover(item: $store.scope(#feature(\.destination?.sheet))) {
        CounterView(store: $0)
      }
    }
  }
}
