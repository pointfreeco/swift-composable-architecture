import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how `Reducer` bodies can recursively nest themselves.

  Tap "Add row" to add a row to the current screen's list. Tap the left-hand side of a row to edit \
  its name, or tap the right-hand side of a row to navigate to its own associated list of rows.
  """

// MARK: - Feature domain

struct Nested: Reducer {
  @ObservableState
  struct State: Equatable, Identifiable {
    let id: UUID
    var name: String = ""
    var rows: IdentifiedArrayOf<State> = []
  }

  enum Action: Equatable {
    case addRowButtonTapped
    case nameTextFieldChanged(String)
    case onDelete(IndexSet)
    indirect case row(id: State.ID, action: Action)
  }

  @Dependency(\.uuid) var uuid

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .addRowButtonTapped:
        state.rows.append(State(id: self.uuid()))
        return .none

      case let .nameTextFieldChanged(name):
        state.name = name
        return .none

      case let .onDelete(indexSet):
        state.rows.remove(atOffsets: indexSet)
        return .none

      case .row:
        return .none
      }
    }
    .forEach(\.rows, action: /Action.row(id:action:)) {
      Self()
    }
  }
}

// MARK: - Feature view

struct NestedView: View {
  let store: StoreOf<Nested>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      ForEachStore(store.scope(state: \.rows, action: { .row(id: $0, action: $1) })) { rowStore in
        NavigationLink(
          destination: NestedView(store: rowStore)
        ) {
          HStack {
            TextField(
              "Untitled",
              text: rowStore.binding(get: \.name, send: { .nameTextFieldChanged($0) })
            )
            Text("Next")
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }
      }
      .onDelete { store.send(.onDelete($0)) }
    }
    .navigationTitle(store.name.isEmpty ? "Untitled" : store.name)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button("Add row") { store.send(.addRowButtonTapped, animation: .default) }
      }
    }
  }
}

extension Nested.State {
  static let mock = Nested.State(
    id: UUID(),
    name: "Foo",
    rows: [
      Nested.State(
        id: UUID(),
        name: "Bar",
        rows: [
          Nested.State(id: UUID(), name: "", rows: [])
        ]
      ),
      Nested.State(
        id: UUID(),
        name: "Baz",
        rows: [
          Nested.State(id: UUID(), name: "Fizz", rows: []),
          Nested.State(id: UUID(), name: "Buzz", rows: []),
        ]
      ),
      Nested.State(id: UUID(), name: "", rows: []),
    ]
  )
}

// MARK: - SwiftUI previews

struct NestedView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      NestedView(
        store: Store(initialState: .mock) {
          Nested()
        }
      )
    }
  }
}
