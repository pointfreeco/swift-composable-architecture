import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state from a list element.

  Tapping a row simultaneously navigates to a screen that depends on its associated counter state \
  and fires off an effect that will load this state a second later.
  """

// MARK: - Feature domain

struct NavigateAndLoadList: ReducerProtocol {
  struct State: Equatable {
    var rows: IdentifiedArrayOf<Row> = [
      Row(count: 1, id: UUID()),
      Row(count: 42, id: UUID()),
      Row(count: 100, id: UUID()),
    ]
    var selection: Identified<Row.ID, Counter.State?>?

    struct Row: Equatable, Identifiable {
      var count: Int
      let id: UUID
    }
  }

  enum Action: Equatable {
    case counter(Counter.Action)
    case setNavigation(selection: UUID?)
    case setNavigationSelectionDelayCompleted
  }

  @Dependency(\.continuousClock) var clock
  private enum CancelID {}

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .counter:
        return .none

      case let .setNavigation(selection: .some(id)):
        state.selection = Identified(nil, id: id)
        return .task {
          try await self.clock.sleep(for: .seconds(1))
          return .setNavigationSelectionDelayCompleted
        }
        .cancellable(id: CancelID.self, cancelInFlight: true)

      case .setNavigation(selection: .none):
        if let selection = state.selection, let count = selection.value?.count {
          state.rows[id: selection.id]?.count = count
        }
        state.selection = nil
        return .cancel(id: CancelID.self)

      case .setNavigationSelectionDelayCompleted:
        guard let id = state.selection?.id else { return .none }
        state.selection?.value = Counter.State(count: state.rows[id: id]?.count ?? 0)
        return .none
      }
    }
    .ifLet(\State.selection, action: /Action.counter) {
      EmptyReducer()
        .ifLet(\Identified<State.Row.ID, Counter.State?>.value, action: .self) {
          Counter()
        }
    }
  }
}

// MARK: - Feature view

struct NavigateAndLoadListView: View {
  let store: StoreOf<NavigateAndLoadList>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }
        ForEach(viewStore.rows) { row in
          NavigationLink(
            destination: IfLetStore(
              self.store.scope(
                state: \.selection?.value,
                action: NavigateAndLoadList.Action.counter
              )
            ) {
              CounterView(store: $0)
            } else: {
              ProgressView()
            },
            tag: row.id,
            selection: viewStore.binding(
              get: \.selection?.id,
              send: NavigateAndLoadList.Action.setNavigation(selection:)
            )
          ) {
            Text("Load optional counter that starts from \(row.count)")
          }
        }
      }
    }
    .navigationTitle("Navigate and load")
  }
}

// MARK: - SwiftUI previews

struct NavigateAndLoadListView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      NavigateAndLoadListView(
        store: Store(
          initialState: NavigateAndLoadList.State(
            rows: [
              NavigateAndLoadList.State.Row(count: 1, id: UUID()),
              NavigateAndLoadList.State.Row(count: 42, id: UUID()),
              NavigateAndLoadList.State.Row(count: 100, id: UUID()),
            ]
          ),
          reducer: NavigateAndLoadList()
        )
      )
    }
    .navigationViewStyle(.stack)
  }
}
