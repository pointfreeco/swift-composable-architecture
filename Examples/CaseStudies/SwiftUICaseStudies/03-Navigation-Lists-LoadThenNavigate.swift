import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state from a list element.

  Tapping a row fires off an effect that will load its associated counter state a second later. \
  When the counter state is present, you will be programmatically navigated to the screen that \
  depends on this data.
  """

struct LoadThenNavigateListState: Equatable {
  var rows: IdentifiedArrayOf<Row> = []
  var selection: Identified<Row.ID, CounterState>?

  struct Row: Equatable, Identifiable {
    var count: Int
    let id: UUID
    var isActivityIndicatorVisible = false
  }
}

enum LoadThenNavigateListAction: Equatable {
  case counter(CounterAction)
  case setNavigation(selection: UUID?)
  case setNavigationSelectionDelayCompleted(UUID)
}

struct LoadThenNavigateListEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let loadThenNavigateListReducer =
  counterReducer
  .pullback(
    state: \Identified.value,
    action: .self,
    environment: { $0 }
  )
  .optional
  .pullback(
    state: \LoadThenNavigateListState.selection,
    action: /LoadThenNavigateListAction.counter,
    environment: { _ in CounterEnvironment() }
  )
  .combined(
    with: Reducer<
      LoadThenNavigateListState, LoadThenNavigateListAction, LoadThenNavigateListEnvironment
    > { state, action, environment in
      struct CancelId: Hashable {}

      switch action {
      case .counter:
        return .none

      case let .setNavigation(selection: .some(id)):
        for index in state.rows.indices {
          state.rows[index].isActivityIndicatorVisible = state.rows[index].id == id
        }

        return Effect(value: .setNavigationSelectionDelayCompleted(id))
          .delay(for: 1, scheduler: environment.mainQueue)
          .eraseToEffect()
          .cancellable(id: CancelId(), cancelInFlight: true)

      case .setNavigation(selection: .none):
        if let selection = state.selection {
          state.rows[id: selection.id]?.count = selection.count
        }
        state.selection = nil
        return .cancel(id: CancelId())

      case let .setNavigationSelectionDelayCompleted(id):
        state.rows[id: id]?.isActivityIndicatorVisible = false
        state.selection = Identified(
          CounterState(count: state.rows[id: id]?.count ?? 0),
          id: id
        )
        return .none
      }
    }
  )

struct LoadThenNavigateListView: View {
  let store: Store<LoadThenNavigateListState, LoadThenNavigateListAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          ForEach(viewStore.rows) { row in
            NavigationLink(
              destination: IfLetStore(
                self.store.scope(
                  state: { $0.selection?.value }, action: LoadThenNavigateListAction.counter),
                then: CounterView.init(store:)
              ),
              tag: row.id,
              selection: viewStore.binding(
                get: { $0.selection?.id },
                send: LoadThenNavigateListAction.setNavigation(selection:)
              )
            ) {
              HStack {
                Text("Load optional counter that starts from \(row.count)")
                if row.isActivityIndicatorVisible {
                  Spacer()
                  ActivityIndicator()
                }
              }
            }
          }
        }
      }
      .navigationBarTitle("Load then navigate")
    }
  }
}

struct LoadThenNavigateListView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LoadThenNavigateListView(
        store: Store(
          initialState: LoadThenNavigateListState(
            rows: [
              .init(count: 1, id: UUID()),
              .init(count: 42, id: UUID()),
              .init(count: 100, id: UUID()),
            ]
          ),
          reducer: loadThenNavigateListReducer,
          environment: LoadThenNavigateListEnvironment(
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
          )
        )
      )
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }
}
