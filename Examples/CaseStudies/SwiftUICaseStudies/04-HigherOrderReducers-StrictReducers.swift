import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how the `Reducer` struct can be extended to enhance reducers with extra \
  functionality.

  In it we introduce a stricter interface for constructing reducers that takes state and action as \
  its only two arguments, and returns a new function that takes the environment as its only \
  argument and returns an effect:
  ```
    (inout State, Action)
      -> (Environment) -> Effect<Action, Never>
  ```
  This form of reducer is useful if you want to be very strict in not allowing the reducer to have \
  access to the environment when it is computing state changes, and only allowing access to the \
  environment when computing effects.

  Tapping "Roll die" below with update die state to a random side using the environment. It uses \
  the strict interface and so it cannot synchronously evaluate its environment to update state. \
  Instead, it introduces a new action to feed the random number back into the system.
  """

extension Reducer {
  static func strict(
    _ reducer: @escaping (inout State, Action) -> (Environment) -> Effect<Action, Never>
  ) -> Reducer {
    Self { state, action, environment in
      reducer(&state, action)(environment)
    }
  }
}

struct DieRollState: Equatable {
  var dieSide = 1
}

enum DieRollAction {
  case rollDie
  case dieRolled(side: Int)
}

struct DieRollEnvironment {
  var rollDie: () -> Int
}

let dieRollReducer = Reducer<DieRollState, DieRollAction, DieRollEnvironment>.strict {
  state, action in
  switch action {
  case .rollDie:
    return { environment in
      Effect(value: .dieRolled(side: environment.rollDie()))
    }

  case let .dieRolled(side):
    state.dieSide = side
    return { _ in .none }
  }
}

struct DieRollView: View {
  let store: Store<DieRollState, DieRollAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(template: readMe, .caption)) {
          HStack {
            Button("Roll die") { viewStore.send(.rollDie) }

            Spacer()

            Text("\(viewStore.dieSide)")
              .font(.body.monospacedDigit())
          }
          .buttonStyle(.borderless)
        }
      }
      .navigationBarTitle("Strict reducers")
    }
  }
}

struct DieRollView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      DieRollView(
        store: Store(
          initialState: DieRollState(),
          reducer: dieRollReducer,
          environment: DieRollEnvironment(
            rollDie: { .random(in: 1...6) }
          )
        )
      )
    }
  }
}
