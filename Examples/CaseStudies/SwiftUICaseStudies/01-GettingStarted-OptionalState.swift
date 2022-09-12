import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how to show and hide views based on the presence of some optional child \
  state.

  The parent state holds a `CounterState?` value. When it is `nil` we will default to a plain text \
  view. But when it is non-`nil` we will show a view fragment for a counter that operates on the \
  non-optional counter state.

  Tapping "Toggle counter state" will flip between the `nil` and non-`nil` counter states.
  """

struct OptionalBasicsState: Equatable {
  var optionalCounter: CounterState?
}

enum OptionalBasicsAction: Equatable {
  case optionalCounter(CounterAction)
  case toggleCounterButtonTapped
}

struct OptionalBasicsEnvironment {}

let optionalBasicsReducer =
  counterReducer
  .optional()
  .pullback(
    state: \.optionalCounter,
    action: /OptionalBasicsAction.optionalCounter,
    environment: { _ in CounterEnvironment() }
  )
  .combined(
    with: Reducer<
      OptionalBasicsState, OptionalBasicsAction, OptionalBasicsEnvironment
    > { state, action, environment in
      switch action {
      case .toggleCounterButtonTapped:
        state.optionalCounter =
          state.optionalCounter == nil
          ? CounterState()
          : nil
        return .none
      case .optionalCounter:
        return .none
      }
    }
  )

struct OptionalBasicsView: View {
  let store: Store<OptionalBasicsState, OptionalBasicsAction>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }

        Button("Toggle counter state") {
          viewStore.send(.toggleCounterButtonTapped)
        }

        IfLetStore(
          self.store.scope(
            state: \.optionalCounter,
            action: OptionalBasicsAction.optionalCounter
          ),
          then: { store in
            Text(template: "`CounterState` is non-`nil`")
            CounterView(store: store)
              .buttonStyle(.borderless)
              .frame(maxWidth: .infinity)
          },
          else: {
            Text(template: "`CounterState` is `nil`")
          }
        )
      }
    }
    .navigationTitle("Optional state")
  }
}

struct OptionalBasicsView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      NavigationView {
        OptionalBasicsView(
          store: Store(
            initialState: OptionalBasicsState(),
            reducer: optionalBasicsReducer,
            environment: OptionalBasicsEnvironment()
          )
        )
      }

      NavigationView {
        OptionalBasicsView(
          store: Store(
            initialState: OptionalBasicsState(optionalCounter: CounterState(count: 42)),
            reducer: optionalBasicsReducer,
            environment: OptionalBasicsEnvironment()
          )
        )
      }
    }
  }
}
