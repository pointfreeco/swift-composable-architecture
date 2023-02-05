import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state from a list element.

  Tapping a row fires off an effect that will load its associated counter state a second later. \
  When the counter state is present, you will be programmatically navigated to the screen that \
  depends on this data.
  """

// MARK: - Feature domain

struct LoadThenNavigateList: ReducerProtocol {
  struct State: Equatable {
    var rows: IdentifiedArrayOf<Row> = [
      Row(count: 1, id: UUID()),
      Row(count: 42, id: UUID()),
      Row(count: 100, id: UUID()),
    ]
    var selection: Identified<Row.ID, Counter.State>?

    struct Row: Equatable, Identifiable {
      var count: Int
      let id: UUID
      var isActivityIndicatorVisible = false
    }
  }

  enum Action: Equatable {
    case counter(Counter.Action)
    case onDisappear
    case setNavigation(selection: UUID?)
    case setNavigationSelectionDelayCompleted(UUID)
  }

  @Dependency(\.continuousClock) var clock
  private enum CancelID {}

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .counter:
        return .none

      case .onDisappear:
        return .cancel(id: CancelID.self)

      case let .setNavigation(selection: .some(navigatedId)):
        for row in state.rows {
          state.rows[id: row.id]?.isActivityIndicatorVisible = row.id == navigatedId
        }
        return .task {
          try await self.clock.sleep(for: .seconds(1))
          return .setNavigationSelectionDelayCompleted(navigatedId)
        }
        .cancellable(id: CancelID.self, cancelInFlight: true)

      case .setNavigation(selection: .none):
        if let selection = state.selection {
          state.rows[id: selection.id]?.count = selection.count
        }
        state.selection = nil
        return .cancel(id: CancelID.self)

      case let .setNavigationSelectionDelayCompleted(id):
        state.rows[id: id]?.isActivityIndicatorVisible = false
        state.selection = Identified(
          Counter.State(count: state.rows[id: id]?.count ?? 0),
          id: id
        )
        return .none
      }
    }
    .ifLet(\.selection, action: /Action.counter) {
      Scope(state: \Identified<State.Row.ID, Counter.State>.value, action: /.self) {
        Counter()
      }
    }
  }
}

// MARK: - Feature view

struct LoadThenNavigateListView: View {
  let store: StoreOf<LoadThenNavigateList>

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
                action: LoadThenNavigateList.Action.counter
              )
            ) {
              CounterView(store: $0)
            },
            tag: row.id,
            selection: viewStore.binding(
              get: \.selection?.id,
              send: LoadThenNavigateList.Action.setNavigation(selection:)
            )
          ) {
            HStack {
              Text("Load optional counter that starts from \(row.count)")
              if row.isActivityIndicatorVisible {
                Spacer()
                ProgressView()
              }
            }
          }
        }
      }
      .navigationTitle("Load then navigate")
      .onDisappear { viewStore.send(.onDisappear) }
    }
  }
}

// MARK: - SwiftUI previews

struct LoadThenNavigateListView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LoadThenNavigateListView(
        store: Store(
          initialState: LoadThenNavigateList.State(
            rows: [
              LoadThenNavigateList.State.Row(count: 1, id: UUID()),
              LoadThenNavigateList.State.Row(count: 42, id: UUID()),
              LoadThenNavigateList.State.Row(count: 100, id: UUID()),
            ]
          ),
          reducer: LoadThenNavigateList()
        )
      )
    }
    .navigationViewStyle(.stack)
  }
}
