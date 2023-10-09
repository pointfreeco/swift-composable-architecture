import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates driving 3 kinds of navigation (drill down, sheet, popover) from a single
  piece of enum state.
  """

struct MultipleDestinations: Reducer {
  public struct Destination: Reducer {
    public enum State: Equatable {
      case drillDown(Counter.State)
      case popover(Counter.State)
      case sheet(Counter.State)
    }

    public enum Action {
      case drillDown(Counter.Action)
      case popover(Counter.Action)
      case sheet(Counter.Action)
    }

    public var body: some Reducer<State, Action> {
      Scope(state: /State.drillDown, action: /Action.drillDown) {
        Counter()
      }
      Scope(state: /State.sheet, action: /Action.sheet) {
        Counter()
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
      .navigationDestination(
        store: self.store.scope(state: \.$destination, action: { .destination($0) }),
        state: /MultipleDestinations.Destination.State.drillDown,
        action: MultipleDestinations.Destination.Action.drillDown
      ) { store in
        CounterView(store: store)
      }
      .popover(
        store: self.store.scope(state: \.$destination, action: { .destination($0) }),
        state: /MultipleDestinations.Destination.State.popover,
        action: MultipleDestinations.Destination.Action.popover
      ) { store in
        CounterView(store: store)
      }
      .sheet(
        store: self.store.scope(state: \.$destination, action: { .destination($0) }),
        state: /MultipleDestinations.Destination.State.sheet,
        action: MultipleDestinations.Destination.Action.sheet
      ) { store in
        CounterView(store: store)
      }
    }
  }
}
