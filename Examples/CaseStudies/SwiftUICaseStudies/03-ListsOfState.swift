import ComposableArchitecture
import SwiftUI

struct CounterRowState: Identifiable, Equatable {
  var counter = CounterState()
  let id: UUID
  var isActive = false

  var selection: Void? {
    get { self.isActive ? () : nil }
    set { self.isActive = newValue != nil }
  }
}

let counterRowReducer =
  Reducer<
    CounterRowState, NavigationAction<CounterAction>, Void
  > { state, action, environment in
    switch action {
    case .isActive:
      return .none
    case let .setNavigation(isActive):
      state.isActive = isActive
      return .none
    }
  }
  .navigates(
    counterReducer,
    tag: /.self,
    selection: \.selection,
    state: \.counter,
    action: /.self,
    environment: { CounterEnvironment() }
  )

struct CounterListState: Equatable {
  var counters: IdentifiedArrayOf<CounterRowState> = []
}

enum CounterListAction {
  case addButtonTapped
  case counterRow(id: CounterRowState.ID, action: NavigationAction<CounterAction>)
}

struct CounterListEnvironment {
  var uuid: () -> UUID
}

let counterListReducer = counterRowReducer
  .forEach(
    state: \.counters,
    action: /CounterListAction.counterRow(id:action:),
    environment: { _ in () }
  )
  .combined(
    with: Reducer<
      CounterListState, CounterListAction, CounterListEnvironment
    > { state, action, environment in
      switch action {
      case .addButtonTapped:
        state.counters.append(.init(id: environment.uuid()))
        return .none

      case .counterRow:
        return .none
      }
    }
  )

struct CounterListView: View {
  let store: Store<CounterListState, CounterListAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      NavigationView {
        List {
          ForEachStore(
            self.store.scope(
              state: \.counters, action: CounterListAction.counterRow(id:action:)
            )
          ) { counterStore in
            WithViewStore(counterStore) { counterViewStore in
              NavigationLink(
                "\(counterViewStore.counter.count)",
                destination: CounterView(
                  store: counterStore.scope(state: \.counter, action: NavigationAction.isActive)
                ),
                isActive: counterViewStore.binding(
                  get: \.isActive,
                  send: NavigationAction.setNavigation(isActive:)
                )
              )
            }
          }
        }
        .navigationBarItems(
          trailing: Button(action: { viewStore.send(.addButtonTapped, animation: .default) }) {
            Image(systemName: "plus")
          }
        )
        .navigationBarTitle("Counters")
      }
    }
  }
}

struct CounterListView_Previews: PreviewProvider {
  static var previews: some View {
    CounterListView(
      store: Store(
        initialState: .init(),
        reducer: counterListReducer,
        environment: .init(
          uuid: UUID.init
        )
      )
    )
  }
}
