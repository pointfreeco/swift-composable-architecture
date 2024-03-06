import ComposableArchitecture
@preconcurrency import SwiftUI

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
    @Shared(.todos)
    var todos: IdentifiedArrayOf<Todo> = []

    var filteredTodoIDs: [Todo.ID] {
      zip(self.todos.ids, self.todos).compactMap { id, todo in
        switch filter {
        case .all:
          return id
        case .active:
          return !todo.isComplete ? id : nil
        case .completed:
          return todo.isComplete ? id : nil
        }
      }
    }
  }

  enum Action: BindableAction, Sendable {
    case addTodoButtonTapped
    case binding(BindingAction<State>)
    case clearCompletedButtonTapped
    case delete(IndexSet)
    case move(IndexSet, Int)
    case onAppear
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.uuid) var uuid
  private enum CancelID { case todoCompletion }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .addTodoButtonTapped:
        state.todos.insert(Todo(id: self.uuid()), at: 0)
        return .none

      case .binding:
        return .none

      case .clearCompletedButtonTapped:
        state.todos.removeAll(where: \.isComplete)
        return .none

      case let .delete(indexSet):
        let filteredTodosIDs = state.filteredTodoIDs
        for index in indexSet {
          state.todos.remove(id: filteredTodosIDs[index])
        }
        return .none

      case var .move(source, destination):
        if state.filter == .completed {
          let filteredTodoIDs = state.filteredTodoIDs
          source = IndexSet(
            source
              .map { filteredTodoIDs[$0] }
              .compactMap { state.todos.index(id: $0) }
          )
          destination =
            (destination < filteredTodoIDs.endIndex
              ? state.todos.index(id: filteredTodoIDs[destination])
              : state.todos.endIndex)
            ?? destination
        }
        state.todos.move(fromOffsets: source, toOffset: destination)
        return .none

      case .onAppear:
        return .run { @MainActor [todos = state.$todos] send in
          for await _ in todos.publisher.removeDuplicates().values {
            withAnimation(.default) {
              todos.wrappedValue.sort { $1.isComplete && !$0.isComplete }
            }
          }
        }
      }
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
          ForEach(store.filteredTodoIDs, id: \.self) { id in
            let index = store.todos.ids.firstIndex(of: id)!
            TodoView(todo: $store.todos[index])
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
      .onAppear {
        store.send(.onAppear)
      }
    }
  }
}

extension PersistenceKey where Self == FileStorageKey<IdentifiedArrayOf<Todo>> {
  static var todos: Self {
    Self(url: URL.documentsDirectory.appending(path: "todos.json"))
  }
}

extension IdentifiedArrayOf<Todo> {
  static let mock: Self = [
    Todo(
      description: "Check Mail",
      id: UUID(),
      isComplete: false
    ),
    Todo(
      description: "Buy Milk",
      id: UUID(),
      isComplete: false
    ),
    Todo(
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
