import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state from a list element.

  Tapping a row simultaneously navigates to a screen that depends on its associated counter state \
  and fires off an effect that will load this state a second later.
  """

struct NavigateAndLoadListState: Equatable {
  var rows: IdentifiedArrayOf<Row> = [
    .init(count: 1, id: UUID()),
    .init(count: 42, id: UUID()),
    .init(count: 100, id: UUID()),
  ]
  var selection: Identified<Row.ID, CounterState?>?

  struct Row: Equatable, Identifiable {
    var count: Int
    let id: UUID
  }
}

enum NavigateAndLoadListAction: Equatable {
  case counter(CounterAction)
  case setNavigation(selection: UUID?)
  case setNavigationSelectionDelayCompleted
}

struct NavigateAndLoadListEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let navigateAndLoadListReducer =
  counterReducer
  .optional()
  .pullback(state: \Identified.value, action: .self, environment: { $0 })
  .optional()
  .pullback(
    state: \NavigateAndLoadListState.selection,
    action: /NavigateAndLoadListAction.counter,
    environment: { _ in CounterEnvironment() }
  )
  .combined(
    with: Reducer<
      NavigateAndLoadListState, NavigateAndLoadListAction, NavigateAndLoadListEnvironment
    > { state, action, environment in

      enum CancelId {}

      switch action {
      case .counter:
        return .none

      case let .setNavigation(selection: .some(id)):
        state.selection = Identified(nil, id: id)

        return Effect(value: .setNavigationSelectionDelayCompleted)
          .delay(for: 1, scheduler: environment.mainQueue)
          .eraseToEffect()
          .cancellable(id: CancelId.self)

      case .setNavigation(selection: .none):
        if let selection = state.selection, let count = selection.value?.count {
          state.rows[id: selection.id]?.count = count
        }
        state.selection = nil
        return .cancel(id: CancelId.self)

      case .setNavigationSelectionDelayCompleted:
        guard let id = state.selection?.id else { return .none }
        state.selection?.value = CounterState(count: state.rows[id: id]?.count ?? 0)
        return .none
      }
    }
  )

struct NavigateAndLoadListView: View {
  let store: Store<NavigateAndLoadListState, NavigateAndLoadListAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          ForEach(viewStore.rows) { row in
            NavigationLink(
              destination: IfLetStore(
                self.store.scope(
                  state: \.selection?.value,
                  action: NavigateAndLoadListAction.counter
                ),
                then: CounterView.init(store:),
                else: ProgressView.init
              ),
              tag: row.id,
              selection: viewStore.binding(
                get: \.selection?.id,
                send: NavigateAndLoadListAction.setNavigation(selection:)
              )
            ) {
              Text("Load optional counter that starts from \(row.count)")
            }
          }
        }
      }
    }
    .navigationBarTitle("Navigate and load")
  }
}

struct NavigateAndLoadListView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      NavigateAndLoadListView(
        store: Store(
          initialState: NavigateAndLoadListState(
            rows: [
              .init(count: 1, id: UUID()),
              .init(count: 42, id: UUID()),
              .init(count: 100, id: UUID()),
            ]
          ),
          reducer: navigateAndLoadListReducer,
          environment: NavigateAndLoadListEnvironment(
            mainQueue: .main
          )
        )
      )
    }
    .navigationViewStyle(.stack)
  }
}
