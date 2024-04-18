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
    case onAppear
    case todoChanged(Todo)
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.uuid) var uuid
  private enum CancelID {
    case todoCompletion
    case todoDebounce
  }

  @Dependency(\.defaultDatabaseQueue) var defaultDatabaseQueue

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

      case var .move(source, destination):
        // if state.filter == .completed {
        //   let filteredTodoIDs = state.filteredTodoIDs
        //   source = IndexSet(
        //     source
        //       .map { filteredTodoIDs[$0] }
        //       .compactMap { state.todos.index(id: $0) }
        //   )
        //   destination =
        //     (destination < filteredTodoIDs.endIndex
        //       ? state.todos.index(id: filteredTodoIDs[destination])
        //       : state.todos.endIndex)
        //     ?? destination
        // }
        // state.todos.move(fromOffsets: source, toOffset: destination)
        return .none

      case .onAppear:
        return .run { _ in
          var migrator = DatabaseMigrator()
          migrator.registerMigration("Create todos") { db in
            try db.create(table: "todo") { t in
              t.autoIncrementedPrimaryKey("id")
              t.column("description", .text)
              t.column("isComplete", .boolean)
            }
          }
          try migrator.migrate(defaultDatabaseQueue)
        }

      case .todoChanged(let todo):
        return .run { _ in
//          try await withTaskCancellation(id: CancelID.todoDebounce, cancelInFlight: true) {
//            try await clock.sleep(for: .seconds(0.3))
            try await defaultDatabaseQueue.write { db in
              try todo.update(db)
            }
//          }
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

extension IdentifiedArray where ID == Todo.ID, Element == Todo {
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
