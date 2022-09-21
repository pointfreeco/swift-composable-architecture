import ComposableArchitecture
import SwiftUI

enum Filter: LocalizedStringKey, CaseIterable, Hashable {
  case all = "All"
  case active = "Active"
  case completed = "Completed"
}

struct AppState: Equatable {
  var editMode: EditMode = .inactive
  var filter: Filter = .all
  var todos: IdentifiedArrayOf<TodoState> = []

  var filteredTodos: IdentifiedArrayOf<TodoState> {
    switch filter {
    case .active: return self.todos.filter { !$0.isComplete }
    case .all: return self.todos
    case .completed: return self.todos.filter(\.isComplete)
    }
  }
}

enum AppAction: Equatable {
  case addTodoButtonTapped
  case clearCompletedButtonTapped
  case delete(IndexSet)
  case editModeChanged(EditMode)
  case filterPicked(Filter)
  case move(IndexSet, Int)
  case sortCompletedTodos
  case todo(id: TodoState.ID, action: TodoAction)
}

struct AppEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var uuid: @Sendable () -> UUID
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  todoReducer.forEach(
    state: \.todos,
    action: /AppAction.todo(id:action:),
    environment: { _ in TodoEnvironment() }
  ),
  Reducer { state, action, environment in
    switch action {
    case .addTodoButtonTapped:
      state.todos.insert(TodoState(id: environment.uuid()), at: 0)
      return .none

    case .clearCompletedButtonTapped:
      state.todos.removeAll(where: \.isComplete)
      return .none

    case let .delete(indexSet):
      state.todos.remove(atOffsets: indexSet)
      return .none

    case let .editModeChanged(editMode):
      state.editMode = editMode
      return .none

    case let .filterPicked(filter):
      state.filter = filter
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

      return .task {
        try await environment.mainQueue.sleep(for: .milliseconds(100))
        return .sortCompletedTodos
      }

    case .sortCompletedTodos:
      state.todos.sort { $1.isComplete && !$0.isComplete }
      return .none

    case .todo(id: _, action: .checkBoxToggled):
      enum TodoCompletionID {}
      return .task {
        try await environment.mainQueue.sleep(for: .seconds(1))
        return .sortCompletedTodos
      }
      .animation()
      .cancellable(id: TodoCompletionID.self, cancelInFlight: true)

    case .todo:
      return .none
    }
  }
)

struct AppView: View {
  let store: Store<AppState, AppAction>
  @ObservedObject var viewStore: ViewStore<ViewState, AppAction>

  init(store: Store<AppState, AppAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init(state:)))
  }

  struct ViewState: Equatable {
    let editMode: EditMode
    let filter: Filter
    let isClearCompletedButtonDisabled: Bool

    init(state: AppState) {
      self.editMode = state.editMode
      self.filter = state.filter
      self.isClearCompletedButtonDisabled = !state.todos.contains(where: \.isComplete)
    }
  }

  var body: some View {
    NavigationView {
      VStack(alignment: .leading) {
        Picker(
          "Filter",
          selection: self.viewStore.binding(get: \.filter, send: AppAction.filterPicked).animation()
        ) {
          ForEach(Filter.allCases, id: \.self) { filter in
            Text(filter.rawValue).tag(filter)
          }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)

        List {
          ForEachStore(
            self.store.scope(state: \.filteredTodos, action: AppAction.todo(id:action:))
          ) {
            TodoView(store: $0)
          }
          .onDelete { self.viewStore.send(.delete($0)) }
          .onMove { self.viewStore.send(.move($0, $1)) }
        }
      }
      .navigationTitle("Todos")
      .navigationBarItems(
        trailing: HStack(spacing: 20) {
          EditButton()
          Button("Clear Completed") {
            self.viewStore.send(.clearCompletedButtonTapped, animation: .default)
          }
          .disabled(self.viewStore.isClearCompletedButtonDisabled)
          Button("Add Todo") { self.viewStore.send(.addTodoButtonTapped, animation: .default) }
        }
      )
      .environment(
        \.editMode,
        self.viewStore.binding(get: \.editMode, send: AppAction.editModeChanged)
      )
    }
    .navigationViewStyle(.stack)
  }
}

extension IdentifiedArray where ID == TodoState.ID, Element == TodoState {
  static let mock: Self = [
    TodoState(
      description: "Check Mail",
      id: UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEDDEADBEEF")!,
      isComplete: false
    ),
    TodoState(
      description: "Buy Milk",
      id: UUID(uuidString: "CAFEBEEF-CAFE-BEEF-CAFE-BEEFCAFEBEEF")!,
      isComplete: false
    ),
    TodoState(
      description: "Call Mom",
      id: UUID(uuidString: "D00DCAFE-D00D-CAFE-D00D-CAFED00DCAFE")!,
      isComplete: true
    ),
  ]
}

struct AppView_Previews: PreviewProvider {
  static var previews: some View {
    AppView(
      store: Store(
        initialState: AppState(todos: .mock),
        reducer: appReducer,
        environment: AppEnvironment(
          mainQueue: .main,
          uuid: { UUID() }
        )
      )
    )
  }
}
