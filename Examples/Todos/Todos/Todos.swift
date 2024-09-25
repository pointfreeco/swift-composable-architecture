import ComposableArchitecture
import GRDB
import SwiftUI

enum Filter: LocalizedStringKey, CaseIterable, Hashable {
  case all = "All"
  case active = "Active"
  case completed = "Completed"
}

private struct TodosRequest: GRDBQuery {
  var filter: Filter

  func fetch(_ db: GRDB.Database) throws -> IdentifiedArrayOf<Todo> {
    switch filter {
    case .all:
      try Todo.all().order(Column("isComplete").asc).fetchIdentifiedArray(db)
    case .active:
      try Todo.all().filter(Column("isComplete") == false).fetchIdentifiedArray(db)
    case .completed:
      try Todo.all().filter(Column("isComplete") == true).fetchIdentifiedArray(db)
    }
  }
}

@Reducer
struct Todos {
  @ObservableState
  struct State: Equatable {
    var editMode: EditMode = .inactive
    var filter: Filter = .all
    @SharedReader(.query(TodosRequest(filter: .all))) var todos: IdentifiedArray = []
  }

  enum Action: BindableAction, Sendable {
    case addTodoButtonTapped
    case binding(BindingAction<State>)
    case clearCompletedButtonTapped
    case delete(IndexSet)
    case move(IndexSet, Int)
    case todoChanged(Todo)
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.defaultDatabaseQueue) var defaultDatabaseQueue
  @Dependency(\.uuid) var uuid

  private enum CancelID {
    case todoCompletion
    case todoDebounce
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .addTodoButtonTapped:
        return .run { _ in
          try defaultDatabaseQueue.inDatabase { db in
            try Todo().insert(db)
          }
        }

      case .binding(\.filter):
        let todos = state.todos
        state.$todos = SharedReader(wrappedValue: todos, .query(TodosRequest(filter: state.filter)))
        return .none

      case .binding:
        return .none

      case .clearCompletedButtonTapped:
        let ids = state.todos.filter(\.isComplete).ids
        return .run { _ in
          try defaultDatabaseQueue.inDatabase { db in
            _ = try Todo.deleteAll(db, ids: ids)
          }
        }

      case let .delete(indexSet):
        let ids = indexSet.map { state.todos[$0].id }
        return .run { _ in
          try defaultDatabaseQueue.inDatabase { db in
            _ = try Todo.deleteAll(db, ids: ids)
          }
        }

      case .move: // var .move(source, destination):
        // if state.filter == .completed {
        //   source = IndexSet(
        //     source
        //       .map { state.filteredTodos[$0] }
        //       .compactMap { state.todos.index(id: $0.id) }
        //   )
        //   destination =
        //     (destination < state.filteredTodos.endIndex
        //       ? state.todos.index(id: state.filteredTodos[destination].id)
        //       : state.todos.endIndex)
        //     ?? destination
        // }
        //
        // state.todos.move(fromOffsets: source, toOffset: destination)
        //
        // return .run { send in
        //   try await self.clock.sleep(for: .milliseconds(100))
        //   await send(.sortCompletedTodos)
        // }
        return .none

      case let .todoChanged(todo):
        return .run { _ in
          // try await withTaskCancellation(id: CancelID.todoDebounce, cancelInFlight: true) {
          //   try await clock.sleep(for: .seconds(0.3))
          try await defaultDatabaseQueue.write { db in
            try todo.update(db)
          }
          // }
        }
      }
    }
  }
}

extension IdentifiedArray {
  subscript(id id: ID, default defaultElement: Element) -> Element {
    get {
      self[id: id] ?? defaultElement
    }
    set {
      self[id: id] = newValue
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
          ForEach(store.todos, id: \.id) { todo in
            TodoView(todo: $store.todos[id: todo.id, default: todo].sending(\.todoChanged))
          }
          .onDelete { store.send(.delete($0)) }
          .onMove { store.send(.move($0, $1)) }
        }
        .animation(.default, value: store.todos)
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

extension IdentifiedArrayOf<Todo> {
  static let mock: Self = [
    Todo(
      description: "Check Mail",
      id: 1,
      isComplete: false
    ),
    Todo(
      description: "Buy Milk",
      id: 2,
      isComplete: false
    ),
    Todo(
      description: "Call Mom",
      id: 3,
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
