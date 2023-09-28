import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how `Reducer` bodies can recursively nest themselves.

  Tap "Add row" to add a row to the current screen's list. Tap the left-hand side of a row to edit \
  its name, or tap the right-hand side of a row to navigate to its own associated list of rows.
  """

// MARK: - Feature domain

struct Nested: Reducer {
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
    WithViewStore(self.store, observe: \.name) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }

        ForEachStore(
          self.store.scope(state: \.rows, action: { .row(id: $0, action: $1) })
        ) { rowStore in
          WithViewStore(rowStore, observe: \.name) { rowViewStore in
            NavigationLink(
              destination: NestedView(store: rowStore)
            ) {
              HStack {
                TextField(
                  "Untitled",
                  text: rowViewStore.binding(send: { .nameTextFieldChanged($0) })
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
