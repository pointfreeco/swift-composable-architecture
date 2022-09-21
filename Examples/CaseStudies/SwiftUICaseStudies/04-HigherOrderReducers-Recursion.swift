import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how the `Reducer` struct can be extended to enhance reducers with extra \
  functionality.

  In it we introduce an interface for constructing reducers that need to be called recursively in \
  order to handle nested state and actions. It is handed itself as its first argument.

  Tap "Add row" to add a row to the current screen's list. Tap the left-hand side of a row to edit \
  its description, or tap the right-hand side of a row to navigate to its own associated list of \
  rows.
  """

extension Reducer {
  static func recurse(
    _ reducer: @escaping (Self, inout State, Action, Environment) -> Effect<Action, Never>
  ) -> Self {

    var `self`: Self!
    self = Self { state, action, environment in
      reducer(self, &state, action, environment)
    }
    return self
  }
}

struct NestedState: Equatable, Identifiable {
  let id: UUID
  var name: String = ""
  var rows: IdentifiedArrayOf<NestedState> = []
}

enum NestedAction: Equatable {
  case addRowButtonTapped
  case nameTextFieldChanged(String)
  case onDelete(IndexSet)
  indirect case row(id: NestedState.ID, action: NestedAction)
}

struct NestedEnvironment {
  var uuid: () -> UUID
}

let nestedReducer = Reducer<
  NestedState, NestedAction, NestedEnvironment
>.recurse { `self`, state, action, environment in
  switch action {
  case .addRowButtonTapped:
    state.rows.append(NestedState(id: environment.uuid()))
    return .none

  case let .nameTextFieldChanged(name):
    state.name = name
    return .none

  case let .onDelete(indexSet):
    state.rows.remove(atOffsets: indexSet)
    return .none

  case .row:
    return self.forEach(
      state: \.rows,
      action: /NestedAction.row(id:action:),
      environment: { $0 }
    )
    .run(&state, action, environment)
  }
}

struct NestedView: View {
  let store: Store<NestedState, NestedAction>

  var body: some View {
    WithViewStore(self.store, observe: \.name) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }

        ForEachStore(
          self.store.scope(state: \.rows, action: NestedAction.row(id:action:))
        ) { childStore in
          WithViewStore(childStore, observe: \.name) { childViewStore in
            NavigationLink(
              destination: NestedView(store: childStore)
            ) {
              HStack {
                TextField(
                  "Untitled",
                  text: childViewStore.binding(send: NestedAction.nameTextFieldChanged)
                )
                Text("Next")
                  .font(.callout)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
        .onDelete { viewStore.send(.onDelete($0)) }
      }
      .navigationTitle(viewStore.state.isEmpty ? "Untitled" : viewStore.state)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Add row") { viewStore.send(.addRowButtonTapped) }
        }
      }
    }
  }
}

extension NestedState {
  static let mock = NestedState(
    id: UUID(),
    name: "Foo",
    rows: [
      NestedState(
        id: UUID(),
        name: "Bar",
        rows: [
          NestedState(id: UUID(), name: "", rows: [])
        ]
      ),
      NestedState(
        id: UUID(),
        name: "Baz",
        rows: [
          NestedState(id: UUID(), name: "Fizz", rows: []),
          NestedState(id: UUID(), name: "Buzz", rows: []),
        ]
      ),
      NestedState(id: UUID(), name: "", rows: []),
    ]
  )
}

#if DEBUG
  struct NestedView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        NestedView(
          store: Store(
            initialState: .mock,
            reducer: nestedReducer,
            environment: NestedEnvironment(
              uuid: UUID.init
            )
          )
        )
      }
    }
  }
#endif
