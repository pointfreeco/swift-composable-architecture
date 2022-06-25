import ComposableArchitecture
import SwiftUI

enum Filter: LocalizedStringKey, CaseIterable, Hashable {
  case all = "All"
  case active = "Active"
  case completed = "Completed"
}

struct AppState: Equatable {
  @BindableState var editMode: EditMode = .inactive
  @BindableState var filter: Filter = .all
  var todos: IdentifiedArrayOf<Todo> = []

  var filteredTodos: IdentifiedArrayOf<Todo> {
    switch filter {
    case .active: return self.todos.filter { !$0.isComplete }
    case .all: return self.todos
    case .completed: return self.todos.filter(\.isComplete)
    }
  }
}

enum AppAction: BindableAction, Equatable {
  case addTodoButtonTapped
  case binding(BindingAction<AppState>)
  case clearCompletedButtonTapped
  case delete(IndexSet)
  case move(IndexSet, Int)
  case sortCompletedTodos
  case todo(id: Todo.ID, action: TodoAction)
}

struct AppEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var uuid: () -> UUID
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
      state.todos.insert(Todo(id: environment.uuid()), at: 0)
      return .none

    case .binding:
      return .none

    case .clearCompletedButtonTapped:
      state.todos.removeAll(where: \.isComplete)
      return .none

    case let .delete(indexSet):
      state.todos.remove(atOffsets: indexSet)
      return .none

    case var .move(source, destination):
      if state.filter != .all {
        source = IndexSet(
          source
            .map { state.filteredTodos[$0] }
            .compactMap { state.todos.index(id: $0.id) }
        )
        destination =
          state.todos.index(id: state.filteredTodos[destination].id)
          ?? destination
      }

      state.todos.move(fromOffsets: source, toOffset: destination)

      return Effect(value: .sortCompletedTodos)
        .delay(for: .milliseconds(100), scheduler: environment.mainQueue)
        .eraseToEffect()

    case .sortCompletedTodos:
      state.todos.sort { $1.isComplete && !$0.isComplete }
      return .none

    case .todo(id: _, action: .checkBoxToggled):
      enum TodoCompletionId {}
      return Effect(value: .sortCompletedTodos)
        .debounce(id: TodoCompletionId.self, for: 1, scheduler: environment.mainQueue.animation())

    case .todo:
      return .none
    }
  }
)
.binding()
.debug()

struct AppView: View {
  let store: Store<AppState, AppAction>
  @ObservedObject var viewStore: ViewStore<ViewState, ViewAction>

  init(store: Store<AppState, AppAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: \.view, action: AppAction.view))
  }

  struct ViewState: Equatable {
    @BindableState var editMode: EditMode
    @BindableState var filter: Filter
    var todos: IdentifiedArrayOf<Todo>
    var isClearCompletedButtonDisabled: Bool { !self.todos.contains(where: \.isComplete) }
  }

  enum ViewAction: BindableAction {
    case addTodoButtonTapped
    case binding(BindingAction<ViewState>)
    case clearCompletedButtonTapped
    case delete(IndexSet)
    case move(IndexSet, Int)
  }

  var body: some View {
    NavigationView {
      VStack(alignment: .leading) {
        Picker(
          "Filter",
          selection: self.viewStore.binding(\.$filter).animation()
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
      .navigationBarTitle("Todos")
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
        self.viewStore.binding(\.$editMode)
      )
    }
    .navigationViewStyle(.stack)
  }
}

private extension AppState {

  var view: AppView.ViewState {
    get { .init(editMode: self.editMode, filter: self.filter, todos: self.todos) }
    set {
      self.editMode = newValue.editMode
      self.filter = newValue.filter
    }
  }
}

private extension AppAction {

  static func view(_ viewAction: AppView.ViewAction) -> Self {
    switch viewAction {
    case .addTodoButtonTapped: return .addTodoButtonTapped
    case let .binding(action): return .binding(action.pullback(\.view))
    case .clearCompletedButtonTapped: return .clearCompletedButtonTapped
    case let .delete(indexSet): return .delete(indexSet)
    case let .move(indexSet, index): return .move(indexSet, index)
    }
  }
}

extension IdentifiedArray where ID == Todo.ID, Element == Todo {
  static let mock: Self = [
    Todo(
      description: "Check Mail",
      id: UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEDDEADBEEF")!,
      isComplete: false
    ),
    Todo(
      description: "Buy Milk",
      id: UUID(uuidString: "CAFEBEEF-CAFE-BEEF-CAFE-BEEFCAFEBEEF")!,
      isComplete: false
    ),
    Todo(
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
          uuid: UUID.init
        )
      )
    )
  }
}
