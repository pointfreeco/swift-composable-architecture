import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state from a list element.

  Tapping a row fires off an effect that will load its associated counter state a second later. \
  When the counter state is present, you will be programmatically navigated to the screen that \
  depends on this data.
  """

struct LazyListNavigationState: Equatable {
  var rows: IdentifiedArrayOf<Row> = []
  var selection: Identified<Row.ID, CounterState>?

  struct Row: Equatable, Identifiable {
    var count: Int
    let id: UUID
    var isActivityIndicatorVisible = false
  }
}

enum LazyListNavigationAction: Equatable {
  case counter(CounterAction)
  case setNavigation(selection: UUID?)
  case setNavigationSelectionDelayCompleted(UUID)
}

struct LazyListNavigationEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let lazyListNavigationReducer = Reducer<
  LazyListNavigationState, LazyListNavigationAction, LazyListNavigationEnvironment
>.combine(
  Reducer { state, action, environment in
    switch action {
    case .counter:
      return .none

    case let .setNavigation(selection: .some(id)):
      for index in state.rows.indices {
        state.rows[index].isActivityIndicatorVisible = state.rows[index].id == id
      }

      struct CancelId: Hashable {}

      return Effect(value: .setNavigationSelectionDelayCompleted(id))
        .delay(for: 1, scheduler: environment.mainQueue)
        .eraseToEffect()
        .cancellable(id: CancelId(), cancelInFlight: true)

    case .setNavigation(selection: .none):
      if let selection = state.selection {
        state.rows[id: selection.id]?.count = selection.count
        state.selection = nil
      }
      return .none

    case let .setNavigationSelectionDelayCompleted(id):
      state.rows[id: id]?.isActivityIndicatorVisible = false
      state.selection = Identified(
        CounterState(count: state.rows[id: id]?.count ?? 0),
        id: id
      )
      return .none
    }
  },
  counterReducer
    .pullback(state: \Identified.value, action: .self, environment: { $0 })
    .optional
    .pullback(
      state: \LazyListNavigationState.selection,
      action: /LazyListNavigationAction.counter,
      environment: { _ in CounterEnvironment() }
    )
)

struct LazyListNavigationView: View {
  let store: Store<LazyListNavigationState, LazyListNavigationAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          ForEach(viewStore.rows) { row in
            NavigationLink(
              destination: IfLetStore(
                self.store.scope(
                  state: { $0.selection?.value }, action: LazyListNavigationAction.counter),
                then: CounterView.init(store:)
              ),
              tag: row.id,
              selection: viewStore.binding(
                get: { $0.selection?.id },
                send: LazyListNavigationAction.setNavigation(selection:)
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

struct LazyListNavigationView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LazyListNavigationView(
        store: Store(
          initialState: LazyListNavigationState(
            rows: [
              .init(count: 1, id: UUID()),
              .init(count: 42, id: UUID()),
              .init(count: 100, id: UUID()),
            ]
          ),
          reducer: lazyListNavigationReducer,
          environment: LazyListNavigationEnvironment(
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
          )
        )
      )
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }
}
