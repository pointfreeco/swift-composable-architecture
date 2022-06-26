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
  var children: IdentifiedArrayOf<NestedState> = []
  let id: UUID
  var description: String = ""
}

indirect enum NestedAction: Equatable {
  case append
  case node(id: NestedState.ID, action: NestedAction)
  case remove(IndexSet)
  case rename(String)
}

struct NestedEnvironment {
  var uuid: () -> UUID
}

let nestedReducer = Reducer<
  NestedState, NestedAction, NestedEnvironment
>.recurse { `self`, state, action, environment in
  switch action {
  case .append:
    state.children.append(NestedState(id: environment.uuid()))
    return .none

  case .node:
    return self.forEach(
      state: \.children,
      action: /NestedAction.node(id:action:),
      environment: { $0 }
    )
    .run(&state, action, environment)

  case let .remove(indexSet):
    state.children.remove(atOffsets: indexSet)
    return .none

  case let .rename(name):
    state.description = name
    return .none
  }
}

struct NestedView: View {
  let store: Store<NestedState, NestedAction>

  var body: some View {
    WithViewStore(self.store.scope(state: \.description)) { viewStore in
      Form {
        Section(header: Text(template: readMe, .caption)) {

          ForEachStore(
            self.store.scope(state: \.children, action: NestedAction.node(id:action:))
          ) { childStore in
            WithViewStore(childStore) { childViewStore in
              HStack {
                TextField(
                  "Untitled",
                  text: childViewStore.binding(get: \.description, send: NestedAction.rename)
                )

                Spacer()

                NavigationLink(
                  destination: NestedView(store: childStore)
                ) {
                  Text("")
                }
              }
            }
          }
          .onDelete { viewStore.send(.remove($0)) }
        }
      }
      .navigationBarTitle(viewStore.state.isEmpty ? "Untitled" : viewStore.state)
      .navigationBarItems(
        trailing: Button("Add row") { viewStore.send(.append) }
      )
    }
  }
}

extension NestedState {
  static let mock = NestedState(
    children: [
      NestedState(
        children: [
          NestedState(
            children: [],
            id: UUID(),
            description: ""
          )
        ],
        id: UUID(),
        description: "Bar"
      ),
      NestedState(
        children: [
          NestedState(
            children: [],
            id: UUID(),
            description: "Fizz"
          ),
          NestedState(
            children: [],
            id: UUID(),
            description: "Buzz"
          ),
        ],
        id: UUID(),
        description: "Baz"
      ),
      NestedState(
        children: [],
        id: UUID(),
        description: ""
      ),
    ],
    id: UUID(),
    description: "Foo"
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
