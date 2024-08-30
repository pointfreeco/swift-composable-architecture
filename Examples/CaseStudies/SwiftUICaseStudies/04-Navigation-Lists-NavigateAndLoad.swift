import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state from a list element.

  Tapping a row simultaneously navigates to a screen that depends on its associated counter state \
  and fires off an effect that will load this state a second later.
  """

@Reducer
struct NavigateAndLoadList {
  @ObservableState
  struct State: Equatable {
    var rows: IdentifiedArrayOf<Row> = [
      Row(count: 1, id: UUID()),
      Row(count: 42, id: UUID()),
      Row(count: 100, id: UUID()),
    ]
    var selectedRowID: UUID?
    var selection: Counter.State?

    struct Row: Equatable, Identifiable {
      var count: Int
      let id: UUID
    }
  }

  enum Action {
    case counter(Counter.Action)
    case setNavigation(selection: UUID?)
    case setNavigationSelectionDelayCompleted
  }

  @Dependency(\.continuousClock) var clock
  private enum CancelID { case load }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .counter:
        return .none

      case let .setNavigation(selection: .some(id)):
        state.selectedRowID = id
        return .run { send in
          try await self.clock.sleep(for: .seconds(1))
          await send(.setNavigationSelectionDelayCompleted)
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)

      case .setNavigation(selection: .none):
        if let selectedRowID = state.selectedRowID, let count = state.selection?.count {
          state.rows[id: selectedRowID]?.count = count
        }
        state.selection = nil
        state.selectedRowID = nil
        return .cancel(id: CancelID.load)

      case .setNavigationSelectionDelayCompleted:
        guard let id = state.selectedRowID else { return .none }
        state.selection = Counter.State(count: state.rows[id: id]?.count ?? 0)
        return .none
      }
    }
    .ifLet(\.selection, action: \.counter) {
      Counter()
    }
  }
}

struct NavigateAndLoadListView: View {
  @Bindable var store: StoreOf<NavigateAndLoadList>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }
      ForEach(store.rows) { row in
        NavigationLink(
          "Load optional counter that starts from \(row.count)",
          tag: row.id,
          selection: .init(
            get: { store.selectedRowID },
            set: { id in store.send(.setNavigation(selection: id)) }
          )
        ) {
          if let store = store.scope(state: \.selection, action: \.counter) {
            CounterView(store: store)
          } else {
            ProgressView()
          }
        }
      }
    }
    .navigationTitle("Navigate and load")
  }
}

#Preview {
  NavigationView {
    NavigateAndLoadListView(
      store: Store(
        initialState: NavigateAndLoadList.State(
          rows: [
            NavigateAndLoadList.State.Row(count: 1, id: UUID()),
            NavigateAndLoadList.State.Row(count: 42, id: UUID()),
            NavigateAndLoadList.State.Row(count: 100, id: UUID()),
          ]
        )
      ) {
        NavigateAndLoadList()
      }
    )
  }
  .navigationViewStyle(.stack)
}
