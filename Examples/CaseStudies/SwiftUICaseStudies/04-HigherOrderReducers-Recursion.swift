import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how `Reducer` bodies can recursively nest themselves.

  Tap "Add row" to add a row to the current screen's list. Tap the left-hand side of a row to edit \
  its name, or tap the right-hand side of a row to navigate to its own associated list of rows.
  """

@Reducer
struct Nested {
  @ObservableState
  struct State: Equatable, Identifiable {
    let id: UUID
    var name: String = ""
    var rows: IdentifiedArrayOf<State> = []

    init(id: UUID? = nil, name: String = "", rows: IdentifiedArrayOf<State> = []) {
      @Dependency(\.uuid) var uuid
      self.id = id ?? uuid()
      self.name = name
      self.rows = rows
    }
  }

  enum Action {
    case addRowButtonTapped
    case nameTextFieldChanged(String)
    case onDelete(IndexSet)
    indirect case rows(IdentifiedActionOf<Nested>)
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

      case .rows:
        return .none
      }
    }
    .forEach(\.rows, action: \.rows) {
      Self()
    }
  }
}

struct NestedView: View {
  @Bindable var store: StoreOf<Nested>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      ForEach(store.scope(state: \.rows, action: \.rows)) { rowStore in
        @Bindable var rowStore = rowStore
        NavigationLink {
          NestedView(store: rowStore)
        } label: {
          HStack {
            TextField("Untitled", text: $rowStore.name.sending(\.nameTextFieldChanged))
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
        Button("Add row") { store.send(.addRowButtonTapped) }
      }
    }
  }
}

#Preview {
  NavigationView {
    NestedView(
      store: Store(
        initialState: Nested.State(
          name: "Foo",
          rows: [
            Nested.State(
              name: "Bar",
              rows: [
                Nested.State()
              ]
            ),
            Nested.State(
              name: "Baz",
              rows: [
                Nested.State(name: "Fizz"),
                Nested.State(name: "Buzz"),
              ]
            ),
            Nested.State(),
          ]
        )
      ) {
        Nested()
      }
    )
  }
}
