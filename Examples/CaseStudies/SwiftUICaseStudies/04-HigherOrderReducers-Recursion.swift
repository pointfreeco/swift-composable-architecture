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
    _ reducer: @escaping (Reducer, inout State, Action, Environment) -> Effect<Action, Never>
  ) -> Reducer {

    var `self`: Reducer!
    self = Reducer { state, action, environment in
      reducer(self, &state, action, environment)
    }
    return self
  }
}

struct NestedState: Equatable, Identifiable {
  var children: [NestedState] = []
  let id: UUID
  var description: String = ""
}

indirect enum NestedAction: Equatable {
  case append
  case exclaim
  case node(index: Int, action: NestedAction)
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

  case .exclaim:
    state.description += "!"
    return .none

  case let .node(index, action):
    return self.run(&state.children[index], action, environment)
      .map { .node(index: index, action: $0) }

  case let .remove(indexSet):
    state.children.remove(atOffsets: indexSet)
    return .none

  case let .rename(name):
    struct ExclaimId: Hashable {}

    state.description = name
    return Effect(value: .exclaim)
      .debounce(id: ExclaimId(), for: 1, scheduler: DispatchQueue.main)
  }
}

struct NestedView: View {
  let store: Store<NestedState, NestedAction>

  var body: some View {
    WithViewStore(self.store.scope(state: { $0.description })) { viewStore in
      Form {
        Section(header: Text(template: readMe, .caption)) {

          ForEachStore(
            self.store.scope(state: { $0.children }, action: NestedAction.node(index:action:))
          ) { childStore in
            WithViewStore(childStore) { childViewStore in
              HStack {
                TextField(
                  "Untitled",
                  text: childViewStore.binding(get: { $0.description }, send: NestedAction.rename)
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
