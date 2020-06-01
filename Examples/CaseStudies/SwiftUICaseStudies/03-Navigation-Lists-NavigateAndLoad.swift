import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates navigation that depends on loading optional state from a list element.

  Tapping a row simultaneously navigates to a screen that depends on its associated counter state \
  and fires off an effect that will load this state a second later.
  """

struct EagerListNavigationState: Equatable {
  var rows: IdentifiedArrayOf<Row> = []
  var selection: Identified<Row.ID, CounterState?>?

  struct Row: Equatable, Identifiable {
    var count: Int
    let id: UUID
  }
}

enum EagerListNavigationAction: Equatable {
  case counter(CounterAction)
  case setNavigation(selection: UUID?)
  case setNavigationSelectionDelayCompleted
}

struct EagerListNavigationEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let eagerListNavigationReducer = counterReducer
  .optional
  .pullback(state: \Identified.value, action: .self, environment: { $0 })
  .optional
  .pullback(
    state: \EagerListNavigationState.selection,
    action: /EagerListNavigationAction.counter,
    environment: { _ in CounterEnvironment() }
  )
  .combined(
    with: Reducer<
      EagerListNavigationState, EagerListNavigationAction, EagerListNavigationEnvironment
    > { state, action, environment in

      struct CancelId: Hashable {}

      switch action {
      case .counter:
        return .none

      case let .setNavigation(selection: .some(id)):
        state.selection = Identified(nil, id: id)

        return Effect(value: .setNavigationSelectionDelayCompleted)
          .delay(for: 1, scheduler: environment.mainQueue)
          .eraseToEffect()
          .cancellable(id: CancelId())

      case .setNavigation(selection: .none):
        if let selection = state.selection, let count = selection.value?.count {
          state.rows[id: selection.id]?.count = count
        }
        state.selection = nil
        return .cancel(id: CancelId())

      case .setNavigationSelectionDelayCompleted:
        guard let id = state.selection?.id else { return .none }
        state.selection?.value = CounterState(count: state.rows[id: id]?.count ?? 0)
        return .none
      }
    }
  )

struct EagerListNavigationView: View {
  let store: Store<EagerListNavigationState, EagerListNavigationAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          ForEach(viewStore.rows) { row in
            NavigationLink(
              destination: IfLetStore(
                self.store.scope(
                  state: { $0.selection?.value }, action: EagerListNavigationAction.counter),
                then: CounterView.init(store:),
                else: ActivityIndicator()
              ),
              tag: row.id,
              selection: viewStore.binding(
                get: { $0.selection?.id },
                send: EagerListNavigationAction.setNavigation(selection:)
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

struct EagerListNavigationView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      EagerListNavigationView(
        store: Store(
          initialState: EagerListNavigationState(
            rows: [
              .init(count: 1, id: UUID()),
              .init(count: 42, id: UUID()),
              .init(count: 100, id: UUID()),
            ]
          ),
          reducer: eagerListNavigationReducer,
          environment: EagerListNavigationEnvironment(
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
          )
        )
      )
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }
}
