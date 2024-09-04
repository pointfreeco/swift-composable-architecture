import ComposableArchitecture
import SwiftUI

enum Filter: LocalizedStringKey, CaseIterable, Hashable {
  case all = "All"
  case active = "Active"
  case completed = "Completed"
}

@Reducer
struct Todos {
  @ObservableState
  struct State: Equatable {
    var editMode: EditMode = .inactive
    var filter: Filter = .all
    var todos: IdentifiedArrayOf<Todo.State> = []

    var filteredTodos: IdentifiedArrayOf<Todo.State> {
      switch filter {
      case .active: return self.todos.filter { !$0.isComplete }
      case .all: return self.todos
      case .completed: return self.todos.filter(\.isComplete)
      }
    }
  }

  enum Action: BindableAction, Sendable {
    case addTodoButtonTapped
    case binding(BindingAction<State>)
    case clearCompletedButtonTapped
    case delete(IndexSet)
    case move(IndexSet, Int)
    case sortCompletedTodos
    case todos(IdentifiedActionOf<Todo>)
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.uuid) var uuid
  private enum CancelID { case todoCompletion }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .addTodoButtonTapped:
        state.todos.insert(Todo.State(id: self.uuid()), at: 0)
        return .none

      case .binding:
        return .none

      case .clearCompletedButtonTapped:
        state.todos.removeAll(where: \.isComplete)
        return .none

      case let .delete(indexSet):
        let filteredTodos = state.filteredTodos
        for index in indexSet {
          state.todos.remove(id: filteredTodos[index].id)
        }
        return .none

      case var .move(source, destination):
        if state.filter == .completed {
          source = IndexSet(
            source
              .map { state.filteredTodos[$0] }
              .compactMap { state.todos.index(id: $0.id) }
          )
          destination =
            (destination < state.filteredTodos.endIndex
              ? state.todos.index(id: state.filteredTodos[destination].id)
              : state.todos.endIndex)
            ?? destination
        }

        state.todos.move(fromOffsets: source, toOffset: destination)

        return .run { send in
          try await self.clock.sleep(for: .milliseconds(100))
          await send(.sortCompletedTodos)
        }

      case .sortCompletedTodos:
        state.todos.sort { $1.isComplete && !$0.isComplete }
        return .none

      case .todos(.element(id: _, action: .binding(\.isComplete))):
        return .run { send in
          try await self.clock.sleep(for: .seconds(1))
          await send(.sortCompletedTodos, animation: .default)
        }
        .cancellable(id: CancelID.todoCompletion, cancelInFlight: true)

      case .todos:
        return .none
      }
    }
    .forEach(\.todos, action: \.todos) {
      Todo()
    }
  }
}

struct AppView: View {
  @Bindable var store: StoreOf<Todos>

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading) {
        Picker("Filter", selection: $store.filter.animation()) {
          ForEach(Filter.allCases, id: \.self) { filter in
            Text(filter.rawValue).tag(filter)
          }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)

        List {
          ForEach(store.scope(state: \.filteredTodos, action: \.todos)) { store in
            TodoView(store: store)
          }
          .onDelete { store.send(.delete($0)) }
          .onMove { store.send(.move($0, $1)) }
        }
      }
      .navigationTitle("Todos")
      .navigationBarItems(
        trailing: HStack(spacing: 20) {
          EditButton()
          Button("Clear Completed") {
            store.send(.clearCompletedButtonTapped, animation: .default)
          }
          .disabled(!store.todos.contains(where: \.isComplete))
          Button("Add Todo") { store.send(.addTodoButtonTapped, animation: .default) }
        }
      )
      .environment(\.editMode, $store.editMode)
    }
  }
}

extension IdentifiedArrayOf<Todo.State> {
  static let mock: Self = [
    Todo.State(
      description: "Check Mail",
      id: UUID(),
      isComplete: false
    ),
    Todo.State(
      description: "Buy Milk",
      id: UUID(),
      isComplete: false
    ),
    Todo.State(
      description: "Call Mom",
      id: UUID(),
      isComplete: true
    ),
  ]
}

#Preview {
  AppView(
    store: Store(initialState: Todos.State(todos: .mock)) {
      Todos()
    }
  )
}
