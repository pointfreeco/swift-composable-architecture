import ComposableArchitecture
import SwiftUI

enum Filter: LocalizedStringKey, CaseIterable, Hashable {
  case all = "All"
  case active = "Active"
  case completed = "Completed"
}

struct AppReducer: ReducerProtocol {
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

  enum Action: Equatable {
    case addTodoButtonTapped
    case clearCompletedButtonTapped
    case delete(IndexSet)
    case editModeChanged(EditMode)
    case filterPicked(Filter)
    case move(IndexSet, Int)
    case sortCompletedTodos
    case todo(id: Todo.State.ID, action: Todo.Action)
  }

  @Dependency(\.mainQueue) var mainQueue
  @Dependency(\.uuid) var uuid

  var body: some ReducerProtocol<State, Action> {
    ForEachReducer(state: \.todos, action: /Action.todo(id:action:)) {
      Todo()
    }

    Reduce { state, action in
      switch action {
      case .addTodoButtonTapped:
        state.todos.insert(.init(id: self.uuid()), at: 0)
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
          .delay(for: .milliseconds(100), scheduler: self.mainQueue)
          .eraseToEffect()

      case .sortCompletedTodos:
        state.todos.sort { $1.isComplete && !$0.isComplete }
        return .none

      case .todo(id: _, action: .checkBoxToggled):
        enum TodoCompletionId {}
        return Effect(value: .sortCompletedTodos)
          .debounce(id: TodoCompletionId.self, for: 1, scheduler: self.mainQueue.animation())

      case .todo:
        return .none
      }
    }
  }
}

struct AppView: View {
  let store: StoreOf<AppReducer>
  @ObservedObject var viewStore: ViewStore<ViewState, AppReducer.Action>

  init(store: StoreOf<AppReducer>) {
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init(state:)))
  }

  struct ViewState: Equatable {
    let editMode: EditMode
    let filter: Filter
    let isClearCompletedButtonDisabled: Bool

    init(state: AppReducer.State) {
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
          selection: self.viewStore.binding(
            get: \.filter,
            send: AppReducer.Action.filterPicked
          )
          .animation()
        ) {
          ForEach(Filter.allCases, id: \.self) { filter in
            Text(filter.rawValue).tag(filter)
          }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)

        List {
          ForEachStore(
            self.store.scope(state: \.filteredTodos, action: AppReducer.Action.todo(id:action:)),
            content: TodoView.init(store:)
          )
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
        self.viewStore.binding(get: \.editMode, send: AppReducer.Action.editModeChanged)
      )
    }
    .navigationViewStyle(.stack)
  }
}

extension IdentifiedArray where ID == Todo.State.ID, Element == Todo.State {
  static let mock: Self = [
    Element(
      description: "Check Mail",
      id: UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEDDEADBEEF")!,
      isComplete: false
    ),
    Element(
      description: "Buy Milk",
      id: UUID(uuidString: "CAFEBEEF-CAFE-BEEF-CAFE-BEEFCAFEBEEF")!,
      isComplete: false
    ),
    Element(
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
        initialState: .init(todos: .mock),
        reducer: AppReducer()
      )
    )
  }
}
